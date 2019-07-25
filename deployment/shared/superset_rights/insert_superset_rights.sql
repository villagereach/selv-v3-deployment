INSERT INTO referencedata.rights (id, description, name, type) VALUES ('89357f27-28af-4861-98f3-f9182539322f', NULL, 'AGGREGATE_CONSUMPTION', 'REPORTS') ON CONFLICT (id) DO NOTHING;
INSERT INTO referencedata.rights (id, description, name, type) VALUES ('01686932-4691-41d4-b4b6-1eeab5632bfb', NULL, 'REPORTED_AND_ORDERED_PRODUCTS', 'REPORTS') ON CONFLICT (id) DO NOTHING;
INSERT INTO referencedata.rights (id, description, name, type) VALUES ('16658de2-8904-4ae0-9d44-bb5514928193', NULL, 'OCCURRENCE_OF_ADJUSTMENTS', 'REPORTS') ON CONFLICT (id) DO NOTHING;
INSERT INTO referencedata.rights (id, description, name, type) VALUES ('9eaa4ec5-cecd-4261-a499-f068314f8f82', NULL, 'SUBMISSION_OF_MONTHLY_REPORTS', 'REPORTS') ON CONFLICT (id) DO NOTHING;
INSERT INTO referencedata.rights (id, description, name, type) VALUES ('a50677c5-b466-4e53-ab8c-a2622df9f1f1', NULL, 'STOCKS_SUMMARY', 'REPORTS') ON CONFLICT (id) DO NOTHING;
INSERT INTO referencedata.rights (id, description, name, type) VALUES ('792aba8e-e0d4-44ac-8533-6b08fd8601df', NULL, 'STOCK_ON_HAND_PER_INSTITUTION', 'REPORTS') ON CONFLICT (id) DO NOTHING;
INSERT INTO referencedata.rights (id, description, name, type) VALUES ('75d22c34-ef92-4e03-8275-1c22dc3f6d83', NULL, 'COMPARISON_OF_CONSUMPTION_BY_REGION', 'REPORTS') ON CONFLICT (id) DO NOTHING;
