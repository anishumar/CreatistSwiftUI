-- Populate 10 users: 5 actors and 5 videographers
-- Make sure to run this after creating the users table with the correct schema

-- 5 Actors
INSERT INTO users (id, name, email, password, profile_image_url, age, genres, payment_mode, work_mode, location, rating, city, country) VALUES
(
    '550e8400-e29b-41d4-a716-446655440001',
    'Emma Thompson',
    'emma.thompson@email.com',
    '$2b$12$hashed_password_here',
    'https://images.unsplash.com/photo-1494790108755-2616b612b786?w=150&h=150&fit=crop&crop=face',
    28,
    '["actor"]',
    'paid',
    'Onsite',
    '{"latitude": 40.7128, "longitude": -74.0060}',
    4.8,
    'New York',
    'USA'
);

INSERT INTO users (id, name, email, password, profile_image_url, age, genres, payment_mode, work_mode, location, rating, city, country) VALUES
(
    '550e8400-e29b-41d4-a716-446655440002',
    'James Wilson',
    'james.wilson@email.com',
    '$2b$12$hashed_password_here',
    'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&h=150&fit=crop&crop=face',
    32,
    '["actor"]',
    'paid',
    'OnsiteOnline',
    '{"latitude": 51.5074, "longitude": -0.1278}',
    4.6,
    'London',
    'UK'
);

INSERT INTO users (id, name, email, password, profile_image_url, age, genres, payment_mode, work_mode, location, rating, city, country) VALUES
(
    '550e8400-e29b-41d4-a716-446655440003',
    'Sophia Rodriguez',
    'sophia.rodriguez@email.com',
    '$2b$12$hashed_password_here',
    'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=150&h=150&fit=crop&crop=face',
    25,
    '["actor"]',
    'free',
    'Online',
    '{"latitude": 19.4326, "longitude": -99.1332}',
    4.4,
    'Mexico City',
    'Mexico'
);

INSERT INTO users (id, name, email, password, profile_image_url, age, genres, payment_mode, work_mode, location, rating, city, country) VALUES
(
    '550e8400-e29b-41d4-a716-446655440004',
    'Michael Chen',
    'michael.chen@email.com',
    '$2b$12$hashed_password_here',
    'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150&h=150&fit=crop&crop=face',
    29,
    '["actor"]',
    'paid',
    'Onsite',
    '{"latitude": 35.6762, "longitude": 139.6503}',
    4.7,
    'Tokyo',
    'Japan'
);

INSERT INTO users (id, name, email, password, profile_image_url, age, genres, payment_mode, work_mode, location, rating, city, country) VALUES
(
    '550e8400-e29b-41d4-a716-446655440005',
    'Isabella Martinez',
    'isabella.martinez@email.com',
    '$2b$12$hashed_password_here',
    'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=150&h=150&fit=crop&crop=face',
    27,
    '["actor"]',
    'paid',
    'OnsiteOnline',
    '{"latitude": 48.8566, "longitude": 2.3522}',
    4.5,
    'Paris',
    'France'
);

-- 5 Videographers
INSERT INTO users (id, name, email, password, profile_image_url, age, genres, payment_mode, work_mode, location, rating, city, country) VALUES
(
    '550e8400-e29b-41d4-a716-446655440006',
    'David Kim',
    'david.kim@email.com',
    '$2b$12$hashed_password_here',
    'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150&h=150&fit=crop&crop=face',
    31,
    '["videographer"]',
    'paid',
    'Onsite',
    '{"latitude": 34.0522, "longitude": -118.2437}',
    4.9,
    'Los Angeles',
    'USA'
);

INSERT INTO users (id, name, email, password, profile_image_url, age, genres, payment_mode, work_mode, location, rating, city, country) VALUES
(
    '550e8400-e29b-41d4-a716-446655440007',
    'Sarah Johnson',
    'sarah.johnson@email.com',
    '$2b$12$hashed_password_here',
    'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150&h=150&fit=crop&crop=face',
    26,
    '["videographer"]',
    'paid',
    'Online',
    '{"latitude": 43.6532, "longitude": -79.3832}',
    4.6,
    'Toronto',
    'Canada'
);

INSERT INTO users (id, name, email, password, profile_image_url, age, genres, payment_mode, work_mode, location, rating, city, country) VALUES
(
    '550e8400-e29b-41d4-a716-446655440008',
    'Alex Thompson',
    'alex.thompson@email.com',
    '$2b$12$hashed_password_here',
    'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=150&h=150&fit=crop&crop=face',
    33,
    '["videographer"]',
    'free',
    'OnsiteOnline',
    '{"latitude": -33.8688, "longitude": 151.2093}',
    4.3,
    'Sydney',
    'Australia'
);

INSERT INTO users (id, name, email, password, profile_image_url, age, genres, payment_mode, work_mode, location, rating, city, country) VALUES
(
    '550e8400-e29b-41d4-a716-446655440009',
    'Maria Garcia',
    'maria.garcia@email.com',
    '$2b$12$hashed_password_here',
    'https://images.unsplash.com/photo-1487412720507-e7ab37603c6f?w=150&h=150&fit=crop&crop=face',
    28,
    '["videographer"]',
    'paid',
    'Onsite',
    '{"latitude": 40.4168, "longitude": -3.7038}',
    4.7,
    'Madrid',
    'Spain'
);

INSERT INTO users (id, name, email, password, profile_image_url, age, genres, payment_mode, work_mode, location, rating, city, country) VALUES
(
    '550e8400-e29b-41d4-a716-446655440010',
    'Ryan O\'Connor',
    'ryan.oconnor@email.com',
    '$2b$12$hashed_password_here',
    'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&h=150&fit=crop&crop=face',
    30,
    '["videographer"]',
    'paid',
    'Online',
    '{"latitude": 52.3676, "longitude": 4.9041}',
    4.8,
    'Amsterdam',
    'Netherlands'
);

-- Verify the data was inserted correctly
SELECT 
    id, 
    name, 
    email, 
    genres, 
    payment_mode, 
    work_mode, 
    location, 
    rating, 
    city, 
    country 
FROM users 
ORDER BY genres, name; 