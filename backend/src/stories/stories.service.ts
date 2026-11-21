import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

const DAY_MS = 24 * 60 * 60 * 1000;

@Injectable()
export class StoriesService {
  constructor(private prisma: PrismaService) {}

  // Stories grouped by author, only ones younger than 24h, of people I follow.
  async feed(myId: string) {
    const follows = await this.prisma.follow.findMany({
      where: { followerId: myId, status: 'ACCEPTED' },
      select: { addresseeId: true },
    });
    const authorIds = [myId, ...follows.map((f) => f.addresseeId)];
    const stories = await this.prisma.story.findMany({
      where: { authorId: { in: authorIds }, createdAt: { gte: new Date(Date.now() - DAY_MS) } },
      orderBy: { createdAt: 'desc' },
      include: {
        author: { select: { id: true, username: true, avatarUrl: true } },
        views: { select: { viewerId: true } },
      },
      take: 300,
    });
    const grouped = new Map<string, { author: any; stories: any[] }>();
    for (const s of stories) {
      if (!grouped.has(s.author.id)) {
        grouped.set(s.author.id, { author: s.author, stories: [] });
      }
      grouped.get(s.author.id)!.stories.push({
        id: s.id,
        mediaUrl: s.mediaUrl,
        overlayText: s.overlayText,
        createdAt: s.createdAt,
        viewed: s.views.some((v) => v.viewerId === myId),
        viewCount: s.views.length,
      });
    }
    const groups = [...grouped.values()];
    // Unseen first, self first of the unseen pile
    groups.sort((a, b) => {
      const aSelf = a.author.id === myId ? 0 : 1;
      const bSelf = b.author.id === myId ? 0 : 1;
      const aSeen = a.stories.every((s) => s.viewed) ? 1 : 0;
      const bSeen = b.stories.every((s) => s.viewed) ? 1 : 0;
      return aSelf - bSelf || aSeen - bSeen;
    });
    return { groups };
  }

  async create(myId: string, dto: { mediaUrl: string; overlayText?: string }) {
    return this.prisma.story.create({
      data: { authorId: myId, mediaUrl: dto.mediaUrl, overlayText: dto.overlayText || '' },
    });
  }

  async view(viewerId: string, storyId: string) {
    const story = await this.prisma.story.findUnique({ where: { id: storyId } });
    if (!story) throw new NotFoundException();
    await this.prisma.storyView.upsert({
      where: { storyId_viewerId: { storyId, viewerId } },
      update: {},
      create: { storyId, viewerId },
    });
    return { ok: true };
  }

  async viewers(myId: string, storyId: string) {
    const story = await this.prisma.story.findUnique({
      where: { id: storyId },
      include: { views: { include: { viewer: { select: { id: true, username: true, avatarUrl: true } } } } },
    });
    if (!story) throw new NotFoundException();
    if (story.authorId !== myId) return { viewers: [] };
    return { viewers: story.views.map((v) => ({ ...v.viewer, seenAt: v.createdAt })) };
  }

  async remove(myId: string, storyId: string) {
    const story = await this.prisma.story.findUnique({ where: { id: storyId } });
    if (!story) throw new NotFoundException();
    if (story.authorId !== myId) return { ok: false };
    await this.prisma.story.delete({ where: { id: storyId } });
    return { ok: true };
  }
}
