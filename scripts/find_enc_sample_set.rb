#!/bin/env ruby

RUN_IN_TEST_MODE = (ARGV[0] == '--test-mode')
record_comparer_runner = RecordComparerRunner.new(:enc, RUN_IN_TEST_MODE, 387)
record_comparer_runner.run