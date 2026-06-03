<?php
$sql = file_get_contents('c:/laragon/www/successmandiri_mobile/success5_sawit (9).sql');
$lines = explode("\n", $sql);
foreach ($lines as $line) {
    if (stripos($line, 'BURHANUDIN') !== false) {
        // Extract table name
        if (preg_match('/INSERT INTO `([^`]+)`/', $line, $matches)) {
            $table = $matches[1];
            preg_match_all("/\([^)]+\)/", $line, $tuples);
            foreach ($tuples[0] as $tuple) {
                if (stripos($tuple, 'BURHANUDIN') !== false) {
                    echo "Table: $table -> " . $tuple . "\n";
                }
            }
        }
    }
}
