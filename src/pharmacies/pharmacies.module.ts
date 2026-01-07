import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Pharmacie } from './entity/pharmacie.entity';
import { PharmaciesService } from './service/pharmacies.service';
import { PharmaciesController } from './controller/pharmacies.controller';

@Module({
  imports: [TypeOrmModule.forFeature([Pharmacie])],
  providers: [PharmaciesService],
  controllers: [PharmaciesController],
})
export class PharmaciesModule {}
