CREATE TABLE IF NOT EXISTS system_users (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    login VARCHAR(100) NOT NULL,
    password VARCHAR(255) NOT NULL,
    active CHAR(1) NOT NULL DEFAULT 'Y',
    name VARCHAR(150) NOT NULL,
    email VARCHAR(190) NOT NULL,
    role VARCHAR(30) NOT NULL DEFAULT 'viewer',
    PRIMARY KEY (id),
    UNIQUE KEY uq_system_users_login (login)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO system_users (id, login, password, active, name, email, role)
VALUES
(
    1,
    'admin',
    '$2y$12$bcXEuhMGN/GMBy.EBsCBkucJHRrLjgpToH9Ituy8D7G0uILYAxRDW',
    'Y',
    'Lab Administrator',
    'admin@lab.invalid',
    'admin'
),
(
    2,
    'analyst',
    '$2y$12$glsroq1FJe5ABos/iX5xxu1WLshoNgE.45B/a4hsEf43y1YOmlU3y',
    'Y',
    'Lab Analyst',
    'analyst@lab.invalid',
    'viewer'
)
ON DUPLICATE KEY UPDATE
    password = VALUES(password),
    active = VALUES(active),
    name = VALUES(name),
    email = VALUES(email),
    role = VALUES(role);
