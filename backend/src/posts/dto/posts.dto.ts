import { IsBoolean, IsEnum, IsNumber, IsOptional, IsString, MaxLength, Max, Min, MinLength } from 'class-validator';

export class CreatePostDto {
  @IsString()
  mediaUrl!: string;

  @IsEnum(['IMAGE', 'VIDEO'])
  mediaType!: 'IMAGE' | 'VIDEO';

  @IsOptional() @IsString() @MaxLength(2200) caption?: string;
  @IsOptional() @IsString() @MaxLength(80) location?: string;
  @IsOptional() @IsNumber() @Min(0.4) @Max(1.91) aspectRatio?: number;
  @IsOptional() @IsBoolean() isReel?: boolean;
}

export class UpdatePostDto {
  @IsOptional() @IsString() @MaxLength(2200) caption?: string;
  @IsOptional() @IsString() @MaxLength(80) location?: string;
}

export class CreateCommentDto {
  @IsString() @MinLength(1) @MaxLength(1000) text!: string;
}
