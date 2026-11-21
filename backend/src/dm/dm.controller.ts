import { Body, Controller, Get, Param, Post, UseGuards } from '@nestjs/common';
import { DmService } from './dm.service';
import { CreateConversationDto, SendMessageDto } from './dto/dm.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser, AuthUser } from '../auth/current-user.decorator';

@Controller('dm')
@UseGuards(JwtAuthGuard)
export class DmController {
  constructor(private dm: DmService) {}

  @Get('conversations')
  list(@CurrentUser() me: AuthUser) {
    return this.dm.listConversations(me);
  }

  @Post('conversations')
  create(@CurrentUser() me: AuthUser, @Body() dto: CreateConversationDto) {
    return this.dm.create(me, dto);
  }

  @Get('conversations/:id/messages')
  messages(@CurrentUser() me: AuthUser, @Param('id') id: string) {
    return this.dm.listMessages(me, id);
  }

  @Post('conversations/:id/messages')
  send(@CurrentUser() me: AuthUser, @Param('id') id: string, @Body() dto: SendMessageDto) {
    return this.dm.sendMessage(me, id, dto);
  }

  @Post('conversations/:id/read')
  read(@CurrentUser() me: AuthUser, @Param('id') id: string) {
    return this.dm.markRead(me, id);
  }
}
