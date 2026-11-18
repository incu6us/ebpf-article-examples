CREATE TABLE orders (
    id          bigserial PRIMARY KEY,
    customer_id int NOT NULL,
    total_cents int NOT NULL
);
INSERT INTO orders (customer_id, total_cents) VALUES
    (42, 1999), (42, 4500), (42, 1250),
    (7, 800), (7, 12000), (13, 3300);
