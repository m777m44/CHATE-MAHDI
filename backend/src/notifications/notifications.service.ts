import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { RealtimeGateway } from './notifications.gateway';

@Injectable()
export class NotificationsService {
  constructor(
    private prisma: PrismaService,
    private rt: RealtimeGateway,
  ) {}

  async notify(userId: string, actorId: string, type: string, entityId = '') {
    if (userId === actorId) return;
    const notification = await this.prisma.notification.create({
      data: { userId, actorId, type, entityId },
      include: { actor: { select: { id: true, username: true, avatarUrl: true } } },
    });
    this.rt.emitToUser(userId, 'notification:new', notification);
  }

  async list(userId: string) {
    const notifications = await this.prisma.notification.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: 100,
      include: { actor: { select: { id: true, username: true, avatarUrl: true } } },
    });
    return { notifications, unread: notifications.filter((n) => !n.read).length };
  }

  async markRead(userId: string, id?: string) {
    await this.prisma.notification.updateMany({
      where: { userId, ...(id ? { id } : {}) },
      data: { read: true },
    });
    return { ok: true };
  }
}
