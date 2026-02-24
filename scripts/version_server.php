<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

// Version database
$versions = [
    '1.0.2' => [
        'version' => '1.0.2',
        'build_number' => '3',
        'download_url' => 'https://your-server.com/updates/updater_v102.exe',
        'release_notes' => "- Stol o\'zgartirish dialogi yaxshilandi\n- Auto-update funksiyasi qo\'shildi\n- Xatoliklar tuzatildi",
        'mandatory' => false,
        'min_supported_version' => '1.0.0',
        'release_date' => '2026-02-23',
        'file_size' => '15.2 MB'
    ],
    '1.0.3' => [
        'version' => '1.0.3',
        'build_number' => '4',
        'download_url' => 'https://your-server.com/updates/updater_v103.exe',
        'release_notes' => "- Yangi hisobotlar qo\'shildi\n- Performance yaxshilandi\n- Xavfsizlik patchlari",
        'mandatory' => true,
        'min_supported_version' => '1.0.1',
        'release_date' => '2026-03-01',
        'file_size' => '16.1 MB'
    ]
];

// Get current version from request
$currentVersion = $_GET['current'] ?? '1.0.0';

// Find latest version
$latestVersion = null;
foreach ($versions as $version => $info) {
    if ($latestVersion === null || version_compare($version, $latestVersion, '>')) {
        $latestVersion = $version;
    }
}

// Check if update is needed
$updateNeeded = version_compare($latestVersion, $currentVersion, '>');

if ($updateNeeded && isset($versions[$latestVersion])) {
    echo json_encode($versions[$latestVersion]);
} else {
    echo json_encode([
        'version' => $currentVersion,
        'update_available' => false,
        'message' => 'Latest version installed'
    ]);
}

// Log update checks
$logEntry = date('Y-m-d H:i:s') . " - Version check from " . $_SERVER['REMOTE_ADDR'] . " - Current: $currentVersion\n";
file_put_contents('update_logs.txt', $logEntry, FILE_APPEND);
?>
