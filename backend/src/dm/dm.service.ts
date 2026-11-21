import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { RealtimeGateway } from '../notifications/notifications.gateway';
import { CreateConversationDto, SendMessageDto } from './dto/dm.dto';

export type Actor = { id: string; username: string };

@Injectable()
export class DmService {
  constructor(
    private prisma: PrismaService,
    private notifications: NotificationsService,
    private rt: RealtimeGateway,
  ) {}

  private async assertParticipant(conversationId: string, userId: string) {
    const p = await this.prisma.participant.findUnique({
      where: { conversationId_userId: { conversationId, userId } },
    });
    if (!p) throw new ForbiddenException('Not a participant');
    return p;
  }

  async listConversations(me: Actor) {
    const participations = await this.prisma.participant.findMany({
      where: { userId: me.id },
      include: {
        conversation: {
          include: {
            participants: { include: { user: { select: { id: true, username: true, avatarUrl: true } } } },
            messages: { orderBy: { createdAt: 'desc' }, take: 1 },
          },
        },
      },
    });
    const conversations = participations
      .map((p) => {
        const c = p.conversation;
        const others = c.participants.filter((x) => x.userId !== me.id).map((x) => x.user);
        const title = c.isGroup ? c.title || 'Group' : (others[0]?.username ?? 'chat');
        const unread = 0;
        return {
          id: c.id,
          isGroup: c.isGroup,
          title,
          participants: c.participants.map((x) => x.user),
          lastMessage: c.messages[0] || null,
          lastReadAt: p.lastReadAt,
          unread,
        };
      })
      .sort((a, b) => new Date(b.lastMessage?.createdAt || b.lastReadAt).getTime() - new Date(a.lastMessage?.createdAt || a.lastReadAt).getTime());
    return { conversations };
  }

  async create(me: Actor, dto: CreateConversationDto) {
    const usernames = dto.participantUsernames.map((u) => u.trim().toLowerCase()).filter(Boolean);
    const users = await this.prisma.user.findMany({ where: { username: { in: usernames } } });
    if (users.length !== usernames.length) throw new NotFoundException('One or more users not found');

    if (!dto.title && usernames.length === 1) {
      // Reuse existing direct conversation if present.
      const mandatory = [me.id, users[0].id].sort();
      const candidates = await this.prisma.conversation.findMany({
        where: { isGroup: false, AND: usernames.map((u) => ({ participants: { some: { user: { username: u } } } })) },
        include: { participants: true },
      });
      const exact = candidates.find(
        (c) => c.participants.length === 2 && c.participants.every((p) => mandatory.includes(p.userId)),
      );
      if (exact) return { conversation: { id: exact.id, isGroup: false, title: users[0].username } };
    }

    const conversation = await this.prisma.conversation.create({
      data: {
        isGroup: users.length > 1,
        title: dto.title || '',
        participants: {
          create: [me.id, ...users.map((u) => u.id)].map((userId) => ({ userId })),
        },
      },
    });
    return {
      conversation: {
        id: conversation.id,
        isGroup: conversation.isGroup,
        title: dto.title || users.map((u) => u.username).join(', '),
      },
    };
  }

  async listMessages(me: Actor, conversationId: string) {
    await this.assertParticipant(conversationId, me.id);
    const messages = await this.prisma.message.findMany({
      where: { conversationId },
      orderBy: { createdAt: 'desc' },
      take: 200,
      include: {
        sender: { select: { id: true, username: true, avatarUrl: true } },
        sharedPost: { include: { author: { select: { username: true } }, _count: { select: { likes: true } } } },
      },
    });
    return { messages: messages.reverse() };
  }

  async sendMessage(me: Actor, conversationId: string, dto: SendMessageDto) {
    await this.assertParticipant(conversationId, me.id);
    const message = await this.prisma.message.create({
      data: {
        conversationId,
        senderId: me.id,
        type: dto.type,
        content: dto.content || '',
        sharedPostId: dto.sharedPostId,
      },
      include: {
        sender: { select: { id: true, username: true, avatarUrl: true } },
        sharedPost: { include: { author: { select: { username: true } } } },
      },
    });

    // Real-time delivery to conversation members + notification persisting.
    const participants = await this.prisma.participant.findMany({
      where: { conversationId },
      include: { user: { select: { id: true, username: true, avatarUrl: true } } },
    });
    for (const p of participants) {
      if (p.userId === me.id) continue;
      this.rt.emitToUser(p.userId, 'message:new', { conversationId, message });
      await this.notifications.notify(p.userId, me.id, 'MESSAGE', conversationId);
    }
    return { message };
  }

  async markRead(me: Actor, conversationId: string) {
    await this.prisma.participant.update({
      where: { conversationId_userId: { conversationId, userId: me.id } },
      data: { lastReadAt: new Date() },
    }).catch(() => {
      throw new ForbiddenException('Not a participant');
    });
    const participants = await this.prisma.participant.findMany({
      where: { conversationId, NOT: { userId: me.id } },
    });
    for (const p of participants) {
      this.rt.emitToUser(p.userId, 'message:read', { conversationId, userId: me.id, at: new Date().toISOString() });
    }
    return { ok: true };
  }

  async typing(me: Actor, conversationId: string, typing: boolean) {
    const me_participant = await this.prisma.participant.findUnique({
      where: { conversationId_userId: { conversationId, userId: me.id } },
    });
    if (!me_participant) return;
    const participants = await this.prisma.participant.findMany({
      where: { conversationId, NOT: { userId: me.id } },
    });
    for (const p of participants) {
      this.rt.emitToUser(p.userId, 'typing', {
        conversationId,
        userId: me.id,
        username: me.username,
        typing,
      });
    }
  }
}
