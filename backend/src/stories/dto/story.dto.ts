import { IsOptional, IsString, MaxLength } from 'class-validator';

export class CreateStoryDto {
  @IsString()
  mediaUrl!: string;

  @IsOptional() @IsString() @MaxLength(140) overlayText?: string;
}
