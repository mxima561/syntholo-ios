WITH test_gate(suite_order, suite, passed, failed, skipped, cancelled) AS (
    VALUES
        (1, 'Content contract', 73, 0, 0, 0),
        (2, 'Unit', 106, 0, 0, 0),
        (3, 'Functional UI', 18, 0, 0, 0),
        (4, 'Shell a11y', 28, 0, 0, 0),
        (5, 'Onboarding a11y', 11, 0, 0, 0),
        (6, 'Rules', 20, 0, 0, 0)
)
SELECT suite_order, suite, passed, failed, skipped, cancelled
FROM test_gate
ORDER BY suite_order;
