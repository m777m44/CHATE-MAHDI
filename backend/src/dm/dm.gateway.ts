import { Logger } from '@nestjs/common';
import { OnGatewayConnection, SubscribeMessage, WebSocketGateway, WebSocketServer } from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { DmService } from './dm.service';

// Handles ephemeral "typing..." events coming from clients. Messages themselves
// flow over REST so they are persisted exactly once.
@WebSocketGateway({ namespace: 'rt' })
export class DmGateway implements OnGatewayConnection {
  @WebSocketServer() server!: Server;
  private logger = new Logger('DmGateway');

  constructor(private dm: DmService) {}

  handleConnection(client: Socket) {
    this.logger.log(`dm socket connected ${client.id}`);
  }

  @SubscribeMessage('typing')
  handleTyping(client: Socket, data: { conversationId: string; typing: boolean }) {
    if (!client.data?.['userId'] || !data?.conversationId) return;
    const me = { id: client.data['userId'], username: client.data['username'] || '' };
    const typing = !!data.typing;
    void this.dm.typing(me, data.conversationId, typing);
  }
}
