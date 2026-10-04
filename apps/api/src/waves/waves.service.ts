import { BadRequestException, ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { ConfigCache } from '../config-cache/config-cache.service';
import { PrismaService } from '../prisma/prisma.service';
import { CreateWaveDto, UpdateWaveDto } from './waves.dto';
import { findClash, fromHHMM, toHHMM, validateWave } from './wave-rules';

type WaveRow = { id: string; type: 'morning' | 'return'; minuteOfDay: number; weekdays: number; active: boolean };
const view = (w: WaveRow) => ({ ...w, time: toHHMM(w.minuteOfDay) });

@Injectable()
export class WavesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly cache: ConfigCache,
  ) {}

  list(universityId: string) {
    return this.cache.get(universityId, 'waves', async () =>
      (await this.prisma.db.wave.findMany({ orderBy: [{ type: 'asc' }, { minuteOfDay: 'asc' }] })).map(view),
    );
  }

  private async check(candidate: { id?: string; type: 'morning' | 'return'; minuteOfDay: number; weekdays: number; active?: boolean }) {
    const problems = validateWave(candidate);
    if (problems.length) throw new BadRequestException(problems);
    if (candidate.active === false) return;
    const others = await this.prisma.db.wave.findMany({ where: { type: candidate.type, active: true } });
    const clash = findClash(candidate, others);
    if (clash) throw new ConflictException(`A ${candidate.type} wave at ${toHHMM(candidate.minuteOfDay)} already exists on one of these days`);
  }

  async create(universityId: string, dto: CreateWaveDto) {
    const data = { type: dto.type, minuteOfDay: fromHHMM(dto.time), weekdays: dto.weekdays };
    await this.check(data);
    const wave = await this.prisma.db.wave.create({ data: { ...data, universityId } });
    await this.cache.invalidate(universityId, 'waves');
    return view(wave);
  }

  async update(universityId: string, id: string, dto: UpdateWaveDto) {
    const existing = await this.prisma.db.wave.findUnique({ where: { id } });
    if (!existing) throw new NotFoundException();
    const next = {
      id,
      type: existing.type,
      minuteOfDay: dto.time ? fromHHMM(dto.time) : existing.minuteOfDay,
      weekdays: dto.weekdays ?? existing.weekdays,
      active: dto.active ?? existing.active,
    };
    await this.check(next);
    const wave = await this.prisma.db.wave.update({ where: { id }, data: { minuteOfDay: next.minuteOfDay, weekdays: next.weekdays, active: next.active } });
    await this.cache.invalidate(universityId, 'waves');
    return view(wave);
  }
}
