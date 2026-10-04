import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsLatitude, IsLongitude, IsOptional, IsString, Matches, MaxLength } from 'class-validator';

export class CreateUniversityDto {
  @ApiProperty() @IsString() @MaxLength(200) name: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(200) nameAr?: string;
  @ApiProperty() @Matches(/^[a-z0-9-]{2,40}$/) slug: string;
  @ApiProperty() @IsLatitude() campusLat: number;
  @ApiProperty() @IsLongitude() campusLng: number;
}
