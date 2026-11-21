import { IsEnum, IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

export class CreateConversationDto {
  @IsString({ each: true })
  @MinLength(1)
  participantUsernames!: string[]; // 1 username = direct chat, 2+ = group

  @IsOptional() @IsString() @MaxLength(80) title?: string;
}

export class SendMessageDto {
  @IsEnum(['TEXT', 'IMAGE', 'VIDEO', 'POST_SHARE'])
  type!: 'TEXT' | 'IMAGE' | 'VIDEO' | 'POST_SHARE';

  @IsOptional() @IsString() @MaxLength(4000) content?: string;
  @IsOptional() @IsString() sharedPostId?: string;
}
