import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { ArrayMaxSize, ArrayMinSize, IsInt, IsNumber, IsOptional, IsString, IsUUID, MaxLength, Min, ValidateNested } from 'class-validator';

export class TierDto {
  @ApiPropertyOptional() @IsOptional() @IsUUID() id?: string;
  @ApiProperty() @IsString() @MaxLength(60) name: string;
  @ApiProperty() @IsNumber() @Min(0) minKm: number;
  @ApiProperty({ nullable: true }) @IsOptional() @IsNumber() maxKm: number | null;
  @ApiProperty() @IsInt() @Min(1) subscriptionPrice: number;
  @ApiProperty() @IsInt() @Min(1) ridePrice: number;
}

export class ReplaceTiersDto {
  @ApiProperty({ type: [TierDto] })
  @ValidateNested({ each: true })
  @Type(() => TierDto)
  @ArrayMinSize(1)
  @ArrayMaxSize(20)
  tiers: TierDto[];
}
