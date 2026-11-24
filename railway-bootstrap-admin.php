<?php
/**
 * Railway first-boot admin for Poznote.
 *
 * Upstream creates an admin profile named 'admin_change_me' with no password
 * hash, which answers to the hard-coded password 'admin'. On a public Railway
 * URL that would hand the instance to the first visitor, so on the first boot
 * this script renames that profile to POZNOTE_ADMIN_USERNAME and gives it the
 * generated POZNOTE_ADMIN_PASSWORD (stored as a bcrypt hash).
 *
 * It runs once: the marker file in the data volume stops it from undoing a
 * password or username the admin later changes in the app. It exits non-zero
 * on any failure so the deploy fails instead of serving the default login.
 */
if (PHP_SAPI !== 'cli') {
    exit(1);
}

$root = '/var/www/html';
$dataDir = $root . '/data';
$marker = $dataDir . '/.railway-admin-initialised';

if (is_file($marker)) {
    fwrite(STDOUT, "railway-bootstrap: admin already initialised, nothing to do\n");
    exit(0);
}

$username = trim((string)(getenv('POZNOTE_ADMIN_USERNAME') ?: 'admin'));
$password = (string)getenv('POZNOTE_ADMIN_PASSWORD');
if ($password === '' || strlen($password) < 12) {
    fwrite(STDERR, "railway-bootstrap: POZNOTE_ADMIN_PASSWORD must be at least 12 characters\n");
    exit(1);
}
if ($username === '' || ctype_digit($username)) {
    fwrite(STDERR, "railway-bootstrap: POZNOTE_ADMIN_USERNAME must be a non-numeric name\n");
    exit(1);
}

require_once $root . '/config.php';
require_once $root . '/users/db_master.php';

try {
    $con = getMasterConnection(); // creates the schema and the default profile
    $stmt = $con->query("SELECT id, username, password_hash FROM users WHERE is_admin = 1 ORDER BY id");
    $admins = $stmt->fetchAll(PDO::FETCH_ASSOC);

    $target = null;
    foreach ($admins as $a) {
        if ($a['username'] === 'admin_change_me' && ($a['password_hash'] === null || $a['password_hash'] === '')) {
            $target = $a;
            break;
        }
    }

    if ($target === null) {
        // An existing install (restored backup, earlier setup): leave it alone.
        fwrite(STDOUT, "railway-bootstrap: no untouched default admin found, leaving accounts as they are\n");
    } else {
        $id = (int)$target['id'];
        if ($username !== 'admin_change_me') {
            $r = updateUserProfile($id, ['username' => $username]);
            if (empty($r['success'])) {
                fwrite(STDERR, "railway-bootstrap: could not rename the admin: " . ($r['error'] ?? 'unknown error') . "\n");
                exit(1);
            }
        }
        if (!setUserPasswordHash($id, $password)) {
            fwrite(STDERR, "railway-bootstrap: could not set the admin password\n");
            exit(1);
        }
        if (getUserPasswordHash($id) === null) {
            fwrite(STDERR, "railway-bootstrap: admin password hash missing after update\n");
            exit(1);
        }
        fwrite(STDOUT, "railway-bootstrap: admin '{$username}' created with the generated password\n");
    }

    if (@file_put_contents($marker, gmdate('c') . "\n") === false) {
        fwrite(STDERR, "railway-bootstrap: could not write $marker\n");
        exit(1);
    }
    @chmod($marker, 0600);
} catch (Throwable $e) {
    fwrite(STDERR, "railway-bootstrap: " . $e->getMessage() . "\n");
    exit(1);
}
exit(0);
