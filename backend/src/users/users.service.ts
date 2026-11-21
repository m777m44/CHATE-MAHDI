import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';

const publicUserSelect = {
  id: true, username: true, name: true, bio: true, avatarUrl: true,
  websiteUrl: true, isPrivate: true, createdAt: true,
};

@Injectable()
export class UsersService {
  constructor(
    private prisma: PrismaService,
    private notifications: NotificationsService,
  ) {}

  async getProfile(viewerId: string, username: string) {
    const user = await this.prisma.user.findUnique({ where: { username } });
    if (!user) throw new NotFoundException('User not found');
    const [followers, following, postsCount, viewerFollow] = await Promise.all([
      this.prisma.follow.count({ where: { addresseeId: user.id, status: 'ACCEPTED' } }),
      this.prisma.follow.count({ where: { followerId: user.id, status: 'ACCEPTED' } }),
      this.prisma.post.count({ where: { authorId: user.id, isReel: false } }),
      this.prisma.follow.findUnique({
        where: { followerId_addresseeId: { followerId: viewerId, addresseeId: user.id } },
      }),
    ]);
    const isSelf = viewerId === user.id;
    const canView = isSelf || !user.isPrivate || viewerFollow?.status === 'ACCEPTED';
    const posts = canView
      ? await this.prisma.post.findMany({
          where: { authorId: user.id, isReel: false },
          orderBy: { createdAt: 'desc' },
          take: 60,
        })
      : [];
    return {
      user: { ...user, followers, following, postsCount },
      isSelf,
      isFollowing: viewerFollow?.status === 'ACCEPTED',
      followRequested: viewerFollow?.status === 'PENDING',
      canView,
      posts,
    };
  }

  async updateProfile(userId: string, dto: { name?: string; bio?: string; avatarUrl?: string; websiteUrl?: string; isPrivate?: boolean }) {
    return this.prisma.user.update({
      where: { id: userId },
      data: dto,
      select: publicUserSelect,
    });
  }

  async follow(followerId: string, username: string) {
    const target = await this.prisma.user.findUnique({ where: { username } });
    if (!target) throw new NotFoundException('User not found');
    if (target.id === followerId) throw new BadRequestException('Cannot follow yourself');

    const existing = await this.prisma.follow.findUnique({
      where: { followerId_addresseeId: { followerId, addresseeId: target.id } },
    });
    if (existing) {
      return { status: existing.status, message: 'Already following/requested' };
    }
    const status = target.isPrivate ? 'PENDING' : 'ACCEPTED';
    await this.prisma.follow.create({ data: { followerId, addresseeId: target.id, status } });
    if (status === 'ACCEPTED') {
      await this.notifications.notify(target.id, followerId, 'FOLLOW', followerId);
    }
    return { status };
  }

  async unfollow(followerId: string, username: string) {
    const target = await this.prisma.user.findUnique({ where: { username } });
    if (!target) throw new NotFoundException('User not found');
    await this.prisma.follow.deleteMany({ where: { followerId, addresseeId: target.id } });
    return { status: 'NONE' };
  }

  async acceptRequest(userId: string, username: string) {
    const requester = await this.prisma.user.findUnique({ where: { username } });
    if (!requester) throw new NotFoundException('User not found');
    const follow = await this.prisma.follow.findUnique({
      where: { followerId_addresseeId: { followerId: requester.id, addresseeId: userId } },
    });
    if (!follow || follow.status !== 'PENDING') throw new ForbiddenException('No pending request');
    await this.prisma.follow.update({
      where: { id: follow.id },
      data: { status: 'ACCEPTED' },
    });
    await this.notifications.notify(userId, requester.id === userId ? userId : requester.id, 'FOLLOW', requester.id);
    return { status: 'ACCEPTED' };
  }

  async list(userId: string, kind: 'followers' | 'following' | 'requests') {
    const where = kind === 'followers'
      ? { addresseeId: userId }
      : { followerId: userId };
    const statusFilter = kind === 'requests' ? { status: 'PENDING' } : { status: 'ACCEPTED' };
    const follows = await this.prisma.follow.findMany({
      where: { ...where, ...statusFilter },
      include: {
        follower: { select: publicUserSelect },
        addressee: { select: publicUserSelect },
      },
      take: 200,
    });
    return {
      users: follows.map((f) => (kind === 'following' ? f.addressee : f.follower)),
    };
  }
}
