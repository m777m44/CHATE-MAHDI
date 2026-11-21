import { Controller, DefaultValuePipe, Get, ParseIntPipe, Query, UseGuards } from '@nestjs/common';
import { FeedService } from './feed.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser, AuthUser } from '../auth/current-user.decorator';

@Controller('feed')
@UseGuards(JwtAuthGuard)
export class FeedController {
  constructor(private feed: FeedService) {}

  @Get('reels')
  reels(
    @CurrentUser() me: AuthUser,
    @Query('page', new DefaultValuePipe(0), new ParseIntPipe()) page: number,
    @Query('limit', new DefaultValuePipe(10), new ParseIntPipe()) limit: number,
  ) {
    return this.feed.home(me.id, true, page, Math.min(limit, 30));
  }

  @Get('home')
  home(
    @CurrentUser() me: AuthUser,
    @Query('page', new DefaultValuePipe(0), new ParseIntPipe()) page: number,
    @Query('limit', new DefaultValuePipe(10), new ParseIntPipe()) limit: number,
  ) {
    return this.feed.home(me.id, false, page, Math.min(limit, 30));
  }
}
