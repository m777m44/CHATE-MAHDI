import { Body, Controller, Delete, Get, Param, Patch, Post, UseGuards } from '@nestjs/common';
import { PostsService } from './posts.service';
import { CreatePostDto, CreateCommentDto, UpdatePostDto } from './dto/posts.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser, AuthUser } from '../auth/current-user.decorator';

@Controller()
@UseGuards(JwtAuthGuard)
export class PostsController {
  constructor(private posts: PostsService) {}

  @Post('posts')
  create(@CurrentUser() me: AuthUser, @Body() dto: CreatePostDto) {
    return this.posts.create(me.id, dto);
  }

  @Patch('posts/:id')
  update(@CurrentUser() me: AuthUser, @Param('id') id: string, @Body() dto: UpdatePostDto) {
    return this.posts.update(me.id, id, dto);
  }

  @Delete('posts/:id')
  remove(@CurrentUser() me: AuthUser, @Param('id') id: string) {
    return this.posts.remove(me.id, id);
  }

  @Get('posts/:id')
  getOne(@CurrentUser() me: AuthUser, @Param('id') id: string) {
    return this.posts.getOne(me.id, id);
  }

  @Post('posts/:id/like')
  like(@CurrentUser() me: AuthUser, @Param('id') id: string) {
    return this.posts.like(me.id, id);
  }

  @Post('posts/:id/save')
  save(@CurrentUser() me: AuthUser, @Param('id') id: string) {
    return this.posts.save(me.id, id);
  }

  @Post('posts/:id/comments')
  comment(@CurrentUser() me: AuthUser, @Param('id') id: string, @Body() dto: CreateCommentDto) {
    return this.posts.comment(me.id, id, dto.text);
  }

  @Get('posts/:id/comments')
  comments(@Param('id') id: string) {
    return this.posts.listComments(id);
  }

  @Get('users/me/bookmarks')
  bookmarks(@CurrentUser() me: AuthUser) {
    return this.posts.listBookmarks(me.id);
  }
}
