import { Controller, Get, HttpCode, Post, UploadedFile, UseGuards, UseInterceptors } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { memoryStorage } from 'multer';
import { MediaService } from './media.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';

@Controller('media')
@UseGuards(JwtAuthGuard)
export class MediaController {
  constructor(private media: MediaService) {}

  @Get('health')
  health() {
    return { ok: true };
  }

  // Multipart upload (field: "file"). Stored on local disk by default, or
  // forwarded to Cloudinary when STORAGE_DRIVER=cloudinary is configured.
  @Post('upload')
  @HttpCode(200)
  @UseInterceptors(
    FileInterceptor('file', {
      storage: memoryStorage(),
      limits: { fileSize: 100 * 1024 * 1024 },
    }),
  )
  async upload(@UploadedFile() file?: Express.Multer.File) {
    if (!file) return { error: 'No file provided (multipart field name must be "file")' };
    return this.media.store(file);
  }
}
