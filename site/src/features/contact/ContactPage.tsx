import { PageHeading, SectionLabel, Button, Input, Textarea } from '@/components/ui';
import { pageMetadata } from '@/lib/seo';

export const contactMetadata = pageMetadata(
  'Contact',
  'Questions, feedback, takedown requests, or business inquiries for Population: Zero.',
  '/contact',
);

export function ContactPage({ sent }: { sent: boolean }) {
  return (
    <main className="mx-auto mt-10 max-w-180">
      <PageHeading eyebrow="CONTACT" title="Get in touch"
        sub="Questions, feedback, bug reports, takedown requests, or business inquiries. Messages go straight to the operator." />

      {sent ? (
        <div className="mt-8 rounded-xl bg-surface p-6">
          <p className="font-display text-[20px] font-bold">Message sent.</p>
          <p className="mt-1 text-[14px] text-ink-mid">The operator reads every message. If you left an email, you may hear back.</p>
        </div>
      ) : (
        <form method="post" action="/api/contact" className="mt-6">
          <SectionLabel>NAME (optional)</SectionLabel>
          <Input name="name" maxLength={80} placeholder="How should we address you?" />
          <SectionLabel>EMAIL (optional — only if you want a reply)</SectionLabel>
          <Input name="email" type="email" maxLength={200} placeholder="you@example.com" />
          {/* 허니팟 — 봇이 채우면 버린다 */}
          <input name="website" tabIndex={-1} autoComplete="off" className="hidden" aria-hidden />
          <SectionLabel>MESSAGE</SectionLabel>
          <Textarea name="body" required minLength={10} maxLength={2000} rows={6} placeholder="What's on your mind?" />
          <Button className="mt-4">Send message</Button>
        </form>
      )}
    </main>
  );
}
