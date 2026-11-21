import { Controller, Get, Query, Post, UseGuards } from '@nestjs/common';
import { NotificationsService } from './notifications.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser, AuthUser } from '../auth/current-user.decorator';

@Controller('notifications')
@UseGuards(JwtAuthGuard)
export class NotificationsController {
  constructor(private notifications: NotificationsService) {}

  @Get()
  list(@CurrentUser() me: AuthUser) {
    return this.notifications.list(me.id);
  }

  @Post('read')
  markRead(@CurrentUser() me: AuthUser, @Query('id') id?: string) {
    return this.notifications.markRead(me.id, id);
  }
}
