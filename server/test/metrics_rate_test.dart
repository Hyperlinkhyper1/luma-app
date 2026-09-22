import 'package:luma_sync_server/metrics_rate.dart';
import 'package:test/test.dart';

void main() {
  test('uses the full time between polls for bursty traffic', () {
    final sampler = MetricsRateSampler();
    expect(
      sampler.add(const MetricsCounters(
        elapsedUs: 0,
        cpuTotal: 1000,
        cpuIdle: 900,
        rxBytes: 1000,
        txBytes: 1000,
        diskReadBytes: 0,
        diskWriteBytes: 0,
      )),
      isNull,
    );
    final rates = sampler.add(const MetricsCounters(
      elapsedUs: 2000000,
      cpuTotal: 1200,
      cpuIdle: 1080,
      rxBytes: 1000,
      txBytes: 201000,
      diskReadBytes: 0,
      diskWriteBytes: 102400,
    ))!;
    expect(rates.cpuPercent, 10);
    expect(rates.txBytesPerSec, 100000);
    expect(rates.diskWriteBytesPerSec, 51200);
  });

  test('does not report a spike when counters reset or polling resumes', () {
    final sampler = MetricsRateSampler();
    sampler.add(const MetricsCounters(elapsedUs: 0, rxBytes: 1000));
    expect(
        sampler
            .add(const MetricsCounters(elapsedUs: 2000000, rxBytes: 100))!
            .rxBytesPerSec,
        isNull);
    expect(
        sampler
            .add(const MetricsCounters(elapsedUs: 12000001, rxBytes: 100000))!
            .rxBytesPerSec,
        isNull);
    expect(
        sampler
            .add(const MetricsCounters(elapsedUs: 14000001, rxBytes: 102000))!
            .rxBytesPerSec,
        1000);
  });
}
