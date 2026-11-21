import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class SearchService {
  constructor(private prisma: PrismaService) {}

  async searchAll(q: string) {
    const query = q.trim().toLowerCase();
    if (!query) return { users: [], hashtags: [], posts: [] };
    const users = await this.prisma.user.findMany({
      where: {
        OR: [
          { username: { contains: query } },
          { name: { contains: query, mode: 'insensitive' } },
        ],
      },
      select: { id: true, username: true, name: true, avatarUrl: true, isPrivate: true },
      take: 20,
    });
    const hashtag = query.replace('#', '');
    const posts = await this.prisma.post.findMany({
      where: {
        OR: [
          { caption: { contains: hashtag } },
          { hashtags: { has: hashtag } },
          { location: { contains: query } },
        ],
      },
      orderBy: { createdAt: 'desc' },
      take: 30,
      select: { id: true, mediaUrl: true, mediaType: true, caption: true, location: true, createdAt: true, isReel: true },
    });
    return { users, hashtags: [], posts };
  }

  async explore(myId: string, page: number) {
    // Simple interest-free heuristic: recent public posts from people I don't follow.
    const follows = await this.prisma.follow.findMany({
      where: { followerId: myId, status: 'ACCEPTED' },
      select: { addresseeId: true },
    });
    const followingIds = follows.map((f) => f.addresseeId);
    const posts = await this.prisma.post.findMany({
      where: { authorId: { notIn: [myId, ...followingIds] }, isReel: false },
      orderBy: { createdAt: 'desc' },
      skip: page * 24,
      take: 24,
      select: { id: true, mediaUrl: true, mediaType: true, createdAt: true, isReel: true },
    });
    return { page, posts };
  }
}
