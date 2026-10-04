import { Body, Controller, Get, NotFoundException, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { AuthUser, CurrentUser, Roles } from '../auth/decorators';
import { PrismaService } from '../prisma/prisma.service';
import { CreateUniversityDto } from './universities.dto';

@ApiTags('universities')
@ApiBearerAuth()
@Controller('universities')
export class UniversitiesController {
  constructor(private readonly prisma: PrismaService) {}

  @Roles('super_admin')
  @Get()
  list() {
    return this.prisma.db.university.findMany({ orderBy: { createdAt: 'asc' } });
  }

  @Roles('super_admin')
  @Post()
  create(@Body() dto: CreateUniversityDto) {
    return this.prisma.db.university.create({ data: dto });
  }

  /** The caller's own university (office, student, driver). */
  @Roles('office', 'student', 'driver')
  @Get('current')
  async current(@CurrentUser() user: AuthUser) {
    const u = await this.prisma.db.university.findUnique({ where: { id: user.universityId! } });
    if (!u) throw new NotFoundException();
    return u;
  }
}
