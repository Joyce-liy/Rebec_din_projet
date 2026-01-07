import { Entity, PrimaryGeneratedColumn, Column } from 'typeorm';

@Entity('pharmacies')
export class Pharmacie {
  @PrimaryGeneratedColumn()
  id: number;

  @Column()
  nom: string;

  @Column({ type: 'text', nullable: true })
  adresse: string;

  @Column({ nullable: true })
  telephone: string;

  @Column({ nullable: true })
  whatsapp: string;

  @Column({
    type: 'geography',
    spatialFeatureType: 'Point',
    srid: 4326,
  })
  localisation: {
    type: string;
    coordinates: number[];
  };
}
