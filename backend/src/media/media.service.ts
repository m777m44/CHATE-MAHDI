import { Injectable, Logger } from '@nestjs/common';
import { randomUUID } from 'crypto';
import * as fs from 'fs';
import * as path from 'path';

export interface StoredMedia {
  url: string;
  storage: 'local' | 'cloudinary';
  bytes: number;
}

@Injectable()
export class MediaService {
  private logger = new Logger('MediaService');

  async store(file: Express.Multer.File): Promise<StoredMedia> {
    if (process.env.STORAGE_DRIVER === 'cloudinary' &&
        process.env.CLOUDINARY_CLOUD_NAME && process.env.CLOUDINARY_API_KEY &&
        process.env.CLOUDINARY_API_SECRET) {
      return this.storeCloudinary(file);
    }
    return this.storeLocal(file);
  }

  private storeLocal(file: Express.Multer.File): StoredMedia {
    const dir = path.join(process.cwd(), 'uploads');
    fs.mkdirSync(dir, { recursive: true });
    const ext = path.extname(file.originalname || '') || '';
    const name = `${Date.now()}-${randomUUID()}${ext}`;
    fs.writeFileSync(path.join(dir, name), file.buffer);
    return {
      url: `/uploads/${name}`,
      storage: 'local',
      bytes: file.size,
    };
  }

  private storeCloudinary(file: Express.Multer.File): Promise<StoredMedia> {
    // Lazy import keeps "cloudinary" optional in local dev.
    return import('cloudinary').then(async (pkg) => {
      const cloud = pkg.v2;
      cloud.config({
        cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
        api_key: process.env.CLOUDINARY_API_KEY,
        api_secret: process.env.CLOUDINARY_API_SECRET,
      });
      const b64 = file.buffer.toString('base64');
      const res = await cloud.uploader.upload(
        `data:${file.mimetype};base64,${b64}`, { resource_type: 'auto' },
      );
      this.logger.log(`uploaded to cloudinary ${res.public_id}`);
      return { url: res.secure_url, storage: 'cloudinary' as const, bytes: file.size };
    });
  }
}
