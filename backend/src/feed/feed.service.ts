import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class FeedService {
  constructor(private prisma: PrismaService) {}

  /**
   * Home feed with cursor pagination (offset based for simplicity & stability).
   * Includes own posts + posts of accepted follows (skip private authors the
   * viewer does not follow).
   */
  async home(myId: string, reelsOnly: boolean, page: number, limit: number) {
    const follows = await this.prisma.follow.findMany({
      where: { followerId: myId, status: 'ACCEPTED' },
      select: { addresseeId: true },
    });
    const authorIds = [myId, ...follows.map((f) => f.addresseeId)];
    const posts = await this.prisma.post.findMany({
      where: { authorId: { in: authorIds }, isReel: reelsOnly ? true : false },
      orderBy: { createdAt: 'desc' },
      skip: Math.max(0, page) * limit,
      take: limit,
      include: {
        author: { select: { id: true, username: true, avatarUrl: true } },
        likes: { where: { userId: myId } },
        bookmarks: { where: { userId: myId } },
        _count: { select: { likes: true, comments: true } },
      },
    });
    return {
      page,
      limit,
      hasMore: posts.length === limit,
      posts: posts.map((p) => ({
        ...p,
        viewerLiked: p.likes.length > 0,
        viewerSaved: p.bookmarks.length > 0,
        likeCount: p._count.likes,
        commentCount: p._count.comments,
        likes: undefined,
        bookmarks: undefined,
        _count: undefined,
      })),
    };
  }
}
