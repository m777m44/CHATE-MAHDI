import { Controller, Get, Param, Query, UseGuards } from '@nestjs/common';
import { SearchService } from './search.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser, AuthUser } from '../auth/current-user.decorator';

@Controller()
@UseGuards(JwtAuthGuard)
export class SearchController {
  constructor(private search: SearchService) {}

  @Get('search')
  searchAll(@Query('q') q: string) {
    return this.search.searchAll(q || '');
  }

  @Get('explore')
  explore(@CurrentUser() me: AuthUser, @Query('page') page = 0) {
    return this.search.explore(me.id, Number(page) || 0);
  }
}
