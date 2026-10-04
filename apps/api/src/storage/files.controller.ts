import { Controller, Get, NotFoundException, Param, Res } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import type { Response } from 'express';
import { Public } from '../auth/decorators';
import { StorageService } from './storage.service';

@ApiTags('files')
@Controller('files')
export class FilesController {
  constructor(private readonly storage: StorageService) {}

  /** The signed token is the authorisation; expired or tampered tokens get 404 (no existence leak). */
  @Public()
  @Get(':token')
  async get(@Param('token') token: string, @Res() res: Response) {
    const ok = this.storage.verify(token);
    if (!ok) throw new NotFoundException();
    const data = await this.storage.read(ok.key).catch(() => {
      throw new NotFoundException();
    });
    res.setHeader('content-type', ok.mime);
    res.setHeader('cache-control', 'private, no-store');
    res.setHeader('x-content-type-options', 'nosniff');
    res.send(data);
  }
}
