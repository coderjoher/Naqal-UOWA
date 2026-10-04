import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';
import { Badge, Button, Card, Input, Table } from './index';

/** Classes must come from design tokens (see packages/design-tokens). */
const TOKEN_CLASS = /^(bg|text|border|shadow|rounded)-(primary|primary-pressed|primary-soft|on-primary|surface|surface-muted|bg|border|text|text-muted|ink|success|success-soft|warning|warning-soft|danger|danger-soft|female-only|female-only-soft|transparent|current|card|sm|md|lg|pill|display|title|headline|body|label|caption|start|center|e-transparent)$/;

function colourClasses(el: Element) {
  return [...el.classList].map((c) => c.replace(/^(hover|focus|disabled|active|placeholder|last):/, '')).filter((c) => /^(bg|text|border|shadow|rounded)-/.test(c));
}

describe('dashboard UI kit', () => {
  it('[T0-05] Button renders with token classes and is keyboard operable', async () => {
    const onClick = vi.fn();
    render(<Button onClick={onClick}>حفظ</Button>);
    const btn = screen.getByRole('button', { name: 'حفظ' });
    expect(btn).toHaveAttribute('type', 'button');
    expect(btn.className).toContain('bg-primary');
    expect(btn.className).toContain('rounded-pill');
    for (const c of colourClasses(btn)) expect(c).toMatch(TOKEN_CLASS);
    await userEvent.tab();
    expect(btn).toHaveFocus();
    await userEvent.keyboard('{Enter}');
    await userEvent.keyboard(' ');
    expect(onClick).toHaveBeenCalledTimes(2);
  });

  it('[T0-05] Button loading state disables and announces busy', () => {
    render(<Button loading>حفظ</Button>);
    const btn = screen.getByRole('button');
    expect(btn).toBeDisabled();
    expect(btn).toHaveAttribute('aria-busy', 'true');
  });

  it('[T0-05] Button variants map to token colours', () => {
    const { rerender } = render(<Button variant="secondary">x</Button>);
    for (const v of ['secondary', 'ink', 'ghost', 'danger'] as const) {
      rerender(<Button variant={v}>x</Button>);
      for (const c of colourClasses(screen.getByRole('button'))) expect(c).toMatch(TOKEN_CLASS);
    }
  });

  it('[T0-05] Input has a visible associated label and announces errors', async () => {
    render(<Input label="البريد الإلكتروني" error="خطأ" />);
    const input = screen.getByLabelText('البريد الإلكتروني');
    expect(input).toHaveAttribute('aria-invalid', 'true');
    expect(input).toHaveAccessibleDescription('خطأ');
    expect(screen.getByRole('alert')).toHaveTextContent('خطأ');
    expect(input.className).toContain('border-danger');
    await userEvent.tab();
    expect(input).toHaveFocus();
    await userEvent.keyboard('abc');
    expect(input).toHaveValue('abc');
  });

  it('[T0-05] Card uses surface + single card shadow, nested cards are flat', () => {
    const { container, rerender } = render(<Card title="عنوان">body</Card>);
    const card = container.querySelector('section')!;
    expect(card.className).toContain('bg-surface');
    expect(card.className).toContain('shadow-card');
    expect(screen.getByRole('heading', { name: 'عنوان' })).toBeInTheDocument();
    rerender(<Card nested>body</Card>);
    expect(container.querySelector('section')!.className).not.toContain('shadow-card');
  });

  it('[T0-05] Badge always carries a word, not colour alone', () => {
    render(<Badge tone="female-only">حافلة طالبات</Badge>);
    const badge = screen.getByText('حافلة طالبات');
    expect(badge).toHaveAttribute('data-tone', 'female-only');
    for (const c of colourClasses(badge)) expect(c).toMatch(TOKEN_CLASS);
  });

  it('[T0-05] Table is semantic with headers, caption and an empty state', () => {
    const cols = [{ key: 'n', header: 'الاسم', cell: (r: { n: string }) => r.n }];
    const { rerender } = render(<Table caption="المستخدمون" columns={cols} rows={[{ n: 'علي' }]} rowKey={(r) => r.n} />);
    expect(screen.getByRole('table', { name: 'المستخدمون' })).toBeInTheDocument();
    expect(screen.getByRole('columnheader', { name: 'الاسم' })).toHaveAttribute('scope', 'col');
    expect(screen.getByRole('cell', { name: 'علي' })).toBeInTheDocument();
    rerender(<Table caption="x" columns={cols} rows={[]} rowKey={(r) => r.n} empty="لا توجد بيانات" />);
    expect(screen.getByText('لا توجد بيانات')).toBeInTheDocument();
  });
});
