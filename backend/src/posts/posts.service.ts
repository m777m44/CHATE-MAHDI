import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { CreatePostDto, UpdatePostDto } from './dto/posts.dto';

const postInclude = {
  author: { select: { id: true, username: true, avatarUrl: true, isPrivate: true } },
  _count: { select: { likes: true, comments: true } },
};

@Injectable()
export class PostsService {
  constructor(
    private prisma: PrismaService,
    private notifications: NotificationsService,
  ) {}

  private async decorate(myId: string, postIds: string[]) {
    const [likes, bookmarks] = await Promise.all([
      this.prisma.like.findMany({ where: { userId: myId, postId: { in: postIds } } }),
      this.prisma.bookmark.findMany({ where: { userId: myId, postId: { in: postIds } } }),
    ]);
    return {
      likedIds: new Set(likes.map((l) => l.postId)),
      bookmarkedIds: new Set(bookmarks.map((b) => b.postId)),
    };
  }

  private decorateOne(myId: string, post: any) {
    return {
      ...post,
      liked: post.likes?.some((l: any) => l.userId === myId) ?? false,
      saved: false,
      viewerLiked: post.likes?.some((l: any) => l.userId === myId) ?? false,
      viewerSaved: post.bookmarks?.some((b: any) => b.userId === myId) ?? false,
      likeCount: post._count?.likes ?? post.likes?.length ?? 0,
      commentCount: post._count?.comments ?? 0,
    };
  }

  async create(myId: string, dto: CreatePostDto) {
    const hashtags = (dto.caption || '').match(/#[\w\u0600-\u06FF]+/g) || [];
    const post = await this.prisma.post.create({
      data: {
        authorId: myId,
        mediaUrl: dto.mediaUrl,
        mediaType: dto.mediaType,
        caption: dto.caption || '',
        location: dto.location || '',
        aspectRatio: dto.aspectRatio ?? 1,
        isReel: dto.isReel ?? false,
        hashtags: hashtags.map((h) => h.toLowerCase()),
      },
      include: { ...postInclude, likes: { where: { userId: myId } }, bookmarks: { where: { userId: myId } } },
    });
    return this.decorateOne(myId, post);
  }

  async update(myId: string, postId: string, dto: UpdatePostDto) {
    const post = await this.prisma.post.findUnique({ where: { id: postId } });
    if (!post) throw new NotFoundException();
    if (post.authorId !== myId) throw new ForbiddenException();
    return this.prisma.post.update({ where: { id: postId }, data: dto });
  }

  async remove(myId: string, postId: string) {
    const post = await this.prisma.post.findUnique({ where: { id: postId } });
    if (!post) throw new NotFoundException();
    if (post.authorId !== myId) throw new ForbiddenException();
    await this.prisma.post.delete({ where: { id: postId } });
    return { ok: true };
  }

  async getOne(myId: string, postId: string) {
    const post = await this.prisma.post.findUnique({
      where: { id: postId },
      include: { ...postInclude, likes: { where: { userId: myId } }, bookmarks: { where: { userId: myId } } },
    });
    if (!post) throw new NotFoundException();
    return this.decorateOne(myId, post);
  }

  async like(myId: string, postId: string) {
    const post = await this.prisma.post.findUnique({ where: { id: postId } });
    if (!post) throw new NotFoundException();
    const like = await this.prisma.like.findUnique({
      where: { postId_userId: { postId, userId: myId } },
    });
    if (like) {
      await this.prisma.like.delete({ where: { id: like.id } });
      return { liked: false };
    }
    await this.prisma.like.create({ data: { postId, userId: myId } });
    if (post.authorId !== myId) {
      await this.notifications.notify(post.authorId, myId, 'LIKE', postId);
    }
    return { liked: true };
  }

  async save(myId: string, postId: string) {
    const existing = await this.prisma.bookmark.findUnique({
      where: { postId_userId: { postId, userId: myId } },
    });
    if (existing) {
      await this.prisma.bookmark.delete({ where: { id: existing.id } });
      return { saved: false };
    }
    await this.prisma.bookmark.create({ data: { postId, userId: myId } });
    return { saved: true };
  }

  async comment(myId: string, postId: string, text: string) {
    const post = await this.prisma.post.findUnique({ where: { id: postId } });
    if (!post) throw new NotFoundException();
    const comment = await this.prisma.comment.create({
      data: { postId, authorId: myId, text },
      include: { author: { select: { id: true, username: true, avatarUrl: true } } },
    });
    if (post.authorId !== myId) {
      await this.notifications.notify(post.authorId, myId, 'COMMENT', postId);
    }
    // mentions -> notifications
    const mentions = (text.match(/@[a-zA-Z0-9._]+/g) || []).map((m) => m.slice(1).toLowerCase());
    for (const username of mentions) {
      const user = await this.prisma.user.findUnique({ where: { username } });
      if (user && user.id !== myId) {
        await this.notifications.notify(user.id, myId, 'MENTION', postId);
      }
    }
    return comment;
  }

  async listComments(postId: string) {
    return {
      comments: await this.prisma.comment.findMany({
        where: { postId },
        orderBy: { createdAt: 'desc' },
        take: 200,
        include: { author: { select: { id: true, username: true, avatarUrl: true } } },
      }),
    };
  }

  async listBookmarks(myId: string) {
    const bookmarks = await this.prisma.bookmark.findMany({
      where: { userId: myId },
      orderBy: { createdAt: 'desc' },
      take: 100,
      include: {
        post: {
          include: { ...postInclude, likes: { where: { userId: myId } }, bookmarks: { where: { userId: myId } } },
        },
      },
    });
    return { posts: bookmarks.filter((b) => b.post).map((b) => this.decorateOne(myId, b.post)) };
  }
}
