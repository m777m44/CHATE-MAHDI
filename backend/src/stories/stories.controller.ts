import { Body, Controller, Delete, Get, Param, Post, UseGuards } from '@nestjs/common';
import { StoriesService } from './stories.service';
import { CreateStoryDto } from './dto/story.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser, AuthUser } from '../auth/current-user.decorator';

@Controller('stories')
@UseGuards(JwtAuthGuard)
export class StoriesController {
  constructor(private stories: StoriesService) {}

  @Get('feed')
  feed(@CurrentUser() me: AuthUser) {
    return this.stories.feed(me.id);
  }

  @Post()
  create(@CurrentUser() me: AuthUser, @Body() dto: CreateStoryDto) {
    return this.stories.create(me.id, dto);
  }

  @Post(':id/view')
  view(@CurrentUser() me: AuthUser, @Param('id') id: string) {
    return this.stories.view(me.id, id);
  }

  @Get(':id/viewers')
  viewers(@CurrentUser() me: AuthUser, @Param('id') id: string) {
    return this.stories.viewers(me.id, id);
  }

  @Delete(':id')
  remove(@CurrentUser() me: AuthUser, @Param('id') id: string) {
    return this.stories.remove(me.id, id);
  }
}
