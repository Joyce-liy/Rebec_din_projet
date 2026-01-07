import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ConfigModule } from '@nestjs/config';
import { PharmaciesModule } from './pharmacies/pharmacies.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),

    TypeOrmModule.forRoot({
      type: 'postgres',
      host: process.env.DB_HOST || 'localhost',
      port: 5432,
      username: process.env.DB_USERNAME || 'postgres',
      password: process.env.DB_PASSWORD || 'lemaire',
      database: process.env.DB_NAME || 'pharmacie_db',
      autoLoadEntities: true,
      synchronize: false, // ⚠️ false maintenant que la DB existe
    }),

    PharmaciesModule,
  ],
})
export class AppModule {}
