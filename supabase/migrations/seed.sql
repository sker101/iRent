insert into properties (title, description, price, region, district, ward, room_type, bedrooms, bathrooms, furnished, status)
values
  ('Spacious 2BR in Masaki', 'Beautiful 2-bedroom apartment with ocean view. Close to supermarkets and embassies. 24/7 security.', 1500000, 'Dar es Salaam', 'Kinondoni', 'Masaki', 'self_contained', 2, 2, true, 'live'),
  ('Cozy Bedsitter in Sinza', 'Affordable bedsitter suitable for a student or bachelor. Near the main road.', 120000, 'Dar es Salaam', 'Kinondoni', 'Sinza', 'bedsitter', 1, 1, false, 'live'),
  ('Modern 3BR House in Mbezi Beach', 'A stand-alone house with a large compound, paved driveway, and electric fence. Perfect for a family.', 2500000, 'Dar es Salaam', 'Kinondoni', 'Mbezi Beach', 'house', 3, 2, false, 'live'),
  ('Single Room in Kijitonyama', 'Quiet and safe neighborhood. Shared bathroom. Ideal for a young professional.', 80000, 'Dar es Salaam', 'Kinondoni', 'Kijitonyama', 'single', 1, 1, false, 'live');

-- Note: We are skipping inserting property_images for this seed to keep it simple,
-- but the UI handles missing cover images gracefully with a placeholder.
