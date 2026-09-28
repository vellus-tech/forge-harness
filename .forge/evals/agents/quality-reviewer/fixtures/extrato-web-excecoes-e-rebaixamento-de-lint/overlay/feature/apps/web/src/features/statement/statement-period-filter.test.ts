import { filterByPeriod } from './utils';

describe('filterByPeriod', () => {
  it('returns entries inside the period', () => {
    const entries = [
      { id: '1', date: '2026-09-01', amountCents: 440 },
      { id: '2', date: '2026-09-15', amountCents: 880 },
    ];
    expect(filterByPeriod(entries, '2026-09-01', '2026-09-30')).toHaveLength(2);
  });
});
