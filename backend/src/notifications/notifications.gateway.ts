import { Logger } from '@nestjs/common';
import {
  OnGatewayConnection,
  OnGatewayDisconnect,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import { JwtService } from '@nestjs/jwt';
import { Server, Socket } from 'socket.io';

// Every authenticated socket joins room "user:<id>" so the API can push
// real-time notifications and message events.
@WebSocketGateway({ cors: { origin: '*' }, namespace: 'rt' })
export class RealtimeGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer() server!: Server;
  private logger = new Logger('RealtimeGateway');

  constructor(private jwt: JwtService) {}

  async handleConnection(client: Socket) {
    try {
      //? token passed as auth payload or query param
      const token = (client.handshake.auth?.token || (client.handshake.query?.token as string)) as string;
      const payload = this.jwt.verify(token, {
        secret: process.env.JWT_ACCESS_SECRET || 'dev-access-secret',
      });
      if (payload?.type !== 'access' || !payload?.sub) throw new Error('bad token');
      client.data.userId = payload.sub;
      client.data.username = payload.username;
      await client.join(`user:${payload.sub}`);
      this.logger.log(`socket connected for user ${payload.sub}`);
    } catch {
      client.emit('rt:error', { message: 'unauthorized' });
      client.disconnect();
    }
  }

  handleDisconnect(client: Socket) {
    this.logger.log(`socket disconnected for user ${client.data?.['userId']}`);
  }

  emitToUser(userId: string, event: string, data: unknown) {
    this.server.to(`user:${userId}`).emit(event, data);
  }

  @SubscribeMessage('ping')
  handlePing(client: Socket) {
    client.emit('pong', { t: Date.now() });
  }
}
