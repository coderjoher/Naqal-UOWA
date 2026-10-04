import { BadRequestException, Injectable } from '@nestjs/common';
import { ConfigCache } from '../config-cache/config-cache.service';
import { PrismaService } from '../prisma/prisma.service';
import { DriverRequirementsDto } from './requirements.dto';

export const DEFAULT_REQUIREMENTS: DriverRequirementsDto = {
  documents: [
    { key: 'national_id', label: 'National ID card', labelAr: 'البطاقة الوطنية', required: true },
    { key: 'driving_licence', label: 'Driving licence', labelAr: 'إجازة السوق', required: true },
    { key: 'vehicle_registration', label: 'Vehicle registration (sanwiya)', labelAr: 'سنوية السيارة', required: true },
  ],
  vehicleTypes: ['coaster', 'minibus'],
  minSeats: 10,
  maxVehicleAgeYears: 15,
};

export interface RegistrationField {
  key: string;
  kind: 'text' | 'phone' | 'document' | 'select' | 'number' | 'year';
  label: string;
  labelAr?: string;
  required: boolean;
  options?: string[];
  min?: number;
  max?: number;
}

@Injectable()
export class DriverRequirementsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly cache: ConfigCache,
  ) {}

  get(universityId: string): Promise<DriverRequirementsDto> {
    return this.cache.get(universityId, 'driver-requirements', async () => {
      const row = await this.prisma.db.driverRequirementSet.findFirst();
      if (!row) return DEFAULT_REQUIREMENTS;
      return {
        documents: row.documents as unknown as DriverRequirementsDto['documents'],
        vehicleTypes: row.vehicleTypes as unknown as string[],
        minSeats: row.minSeats,
        maxVehicleAgeYears: row.maxVehicleAgeYears,
      };
    });
  }

  async set(universityId: string, dto: DriverRequirementsDto) {
    const keys = dto.documents.map((d) => d.key);
    if (new Set(keys).size !== keys.length) throw new BadRequestException('Document keys must be unique');
    if (dto.vehicleTypes.length === 0) throw new BadRequestException('Allow at least one vehicle type');
    const data = { documents: dto.documents as object[], vehicleTypes: dto.vehicleTypes, minSeats: dto.minSeats, maxVehicleAgeYears: dto.maxVehicleAgeYears };
    await this.prisma.db.driverRequirementSet.upsert({ where: { universityId }, create: data as never, update: data });
    await this.cache.invalidate(universityId, 'driver-requirements');
    return this.get(universityId);
  }

  /**
   * The driver registration form, derived from the office's requirements (TO-01 → DR-01).
   * The driver app renders exactly these fields.
   */
  async registrationForm(universityId: string, now = new Date()): Promise<RegistrationField[]> {
    const r = await this.get(universityId);
    const year = now.getFullYear();
    return [
      { key: 'name', kind: 'text', label: 'Full name', labelAr: 'الاسم الكامل', required: true },
      { key: 'phone', kind: 'phone', label: 'Phone', labelAr: 'رقم الهاتف', required: true },
      { key: 'vehicle_type', kind: 'select', label: 'Vehicle type', labelAr: 'نوع المركبة', required: true, options: r.vehicleTypes },
      { key: 'plate', kind: 'text', label: 'Plate number', labelAr: 'رقم اللوحة', required: true },
      { key: 'seats', kind: 'number', label: 'Passenger seats', labelAr: 'عدد المقاعد', required: true, min: r.minSeats, max: 80 },
      { key: 'model_year', kind: 'year', label: 'Model year', labelAr: 'سنة الصنع', required: true, min: year - r.maxVehicleAgeYears, max: year + 1 },
      ...r.documents.map<RegistrationField>((d) => ({ key: `doc_${d.key}`, kind: 'document', label: d.label, labelAr: d.labelAr, required: d.required })),
    ];
  }
}
