import { Body, Controller, Delete, Get, Param, Patch, Post, Query, UseGuards } from '@nestjs/common';
import { UsersService } from './users.service';
import { UpdateProfileDto } from './dto/users.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser, AuthUser } from '../auth/current-user.decorator';

@Controller('users')
@UseGuards(JwtAuthGuard)
export class UsersController {
  constructor(private users: UsersService) {}

  @Get(':username')
  profile(@CurrentUser() me: AuthUser, @Param('username') username: string) {
    return this.users.getProfile(me.id, username);
  }

  @Patch('me')
  updateProfile(@CurrentUser() me: AuthUser, @Body() dto: UpdateProfileDto) {
    return this.users.updateProfile(me.id, dto);
  }

  @Post(':username/follow')
  follow(@CurrentUser() me: AuthUser, @Param('username') username: string) {
    return this.users.follow(me.id, username);
  }

  @Delete(':username/follow')
  unfollow(@CurrentUser() me: AuthUser, @Param('username') username: string) {
    return this.users.unfollow(me.id, username);
  }

  @Post(':username/follow/accept')
  accept(@CurrentUser() me: AuthUser, @Param('username') username: string) {
    return this.users.acceptRequest(me.id, username);
  }

  @Get('me/connections')
  connections(@CurrentUser() me: AuthUser, @Query('kind') kind: 'followers' | 'following' | 'requests') {
    return this.users.list(me.id, kind || 'followers');
  }
}
