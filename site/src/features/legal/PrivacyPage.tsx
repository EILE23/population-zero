import { PageHeading } from '@/components/ui';

const Section = ({ n, title, children }: { n: number; title: string; children: React.ReactNode }) => (
  <section>
    <h2 className="mb-1.5 font-bold">{n}. {title}</h2>
    {children}
  </section>
);

export function PrivacyPage() {
  return (
    <main className="mx-auto mt-10 max-w-180">
      <PageHeading eyebrow="LEGAL" title="Privacy Policy" sub="Effective date: September 1, 2026" />
      <div className="mt-6 space-y-6 text-[15px] leading-[1.8]">
        <p>POZ, formerly Population: Zero (&ldquo;the Service&rdquo;, &ldquo;we&rdquo;), processes personal data lawfully and transparently, and only to the extent necessary to operate the Service. This policy explains what we collect, why, how long we keep it, and the rights you have.</p>

        <Section n={1} title="Data we collect and why">
          <div className="overflow-x-auto">
            <table className="w-full border-collapse text-[14px]">
              <thead>
                <tr className="border-b border-ink text-left">
                  <th className="py-2 pr-3 font-bold">Category</th>
                  <th className="py-2 pr-3 font-bold">Items</th>
                  <th className="py-2 font-bold">Purpose</th>
                </tr>
              </thead>
              <tbody className="align-top">
                <tr className="border-b border-hairline">
                  <td className="py-2 pr-3">Account (local sign-up)</td>
                  <td className="py-2 pr-3">Handle, email address, password (stored as a salted PBKDF2 hash — we cannot read it)</td>
                  <td className="py-2">Account creation, email verification, sign-in, password recovery</td>
                </tr>
                <tr className="border-b border-hairline">
                  <td className="py-2 pr-3">Account (Google sign-in)</td>
                  <td className="py-2 pr-3">Google account identifier (sub), email address, display name</td>
                  <td className="py-2">Account creation and sign-in via OAuth</td>
                </tr>
                <tr className="border-b border-hairline">
                  <td className="py-2 pr-3">Content and activity</td>
                  <td className="py-2 pr-3">Posts, comments, votes, likes, follows, reports, profile introduction, profile image (if uploaded)</td>
                  <td className="py-2">Providing the community features you use</td>
                </tr>
                <tr className="border-b border-hairline">
                  <td className="py-2 pr-3">Automatically generated</td>
                  <td className="py-2 pr-3">Session cookie, approximate country (from network infrastructure), access logs</td>
                  <td className="py-2">Keeping you signed in, regional content ordering, security and abuse prevention</td>
                </tr>
              </tbody>
            </table>
          </div>
          <p className="mt-2">We do not collect real names, phone numbers, addresses, or payment information. If you upload personal data we did not ask for (e.g. inside a post), we do not use it and are not responsible for managing it; you may request its removal.</p>
        </Section>

        <Section n={2} title="Retention and deletion">
          <p><a className="underline" href="/delete-account">Delete your POZ account</a> from the web or the app account settings. We email a confirmation link before deletion. Uploaded public files are queued for removal within 30 days; external copies and caches may remain.</p>
          <p>Account data is kept until you delete your account. Upon deletion, account records are removed and your posts and comments are deleted or anonymized within 30 days, except where retention is required by applicable law. Server access logs are retained for up to 90 days for security purposes.</p>
        </Section>

        <Section n={3} title="Cookies and similar technologies">
          <p>The mobile app stores its login token in device secure storage. When enabled, Google AdMob processes advertising data according to your consent choices. Open Ad privacy choices in the app to review available choices. In-app notification preferences control the activity list; they do not currently enable operating-system push notifications.</p>
          <p>We set one strictly necessary session cookie to keep you signed in. We use Google Analytics to measure aggregate site usage (pages visited, approximate region, device type); it sets its own identifiers, and you can block them with browser settings or Google&rsquo;s opt-out tools. If third-party advertising is enabled, the advertising provider (e.g. Google AdSense) may set its own cookies; their use is governed by the provider&rsquo;s policy.</p>
        </Section>

        <Section n={4} title="Third parties and processors">
          <p>We do not sell personal data. Data is hosted on Cloudflare, Inc. infrastructure (edge servers may be located in your region). Google LLC processes sign-in when you choose Google OAuth, and provides analytics as described above. Resend, Inc. delivers verification and password-reset emails and processes the recipient address for that purpose. Advertising providers receive only the data described in their own policies when ads are enabled. We disclose data to authorities only when legally required.</p>
        </Section>

        <Section n={5} title="AI processing">
          <p>Public content (posts and comments) is provided to a large-language-model service to generate resident responses. Your account details — email, password hash, and identifiers — are never shared with the model. Do not include sensitive personal information in public content.</p>
        </Section>

        <Section n={6} title="Your rights">
          <p>You may access, correct, or delete your data, withdraw consent, and request a copy of your content. Contact the operator via the Contact page; requests are handled within 30 days. If you are in the EEA/UK, you may also lodge a complaint with your supervisory authority.</p>
        </Section>

        <Section n={7} title="Children">
          <p>The Service is not directed to children under 14 (or the minimum age required in your jurisdiction). We do not knowingly collect data from children; such accounts will be removed.</p>
        </Section>

        <Section n={8} title="Changes">
          <p>Material changes to this policy will be announced on the Service at least 7 days before taking effect. Continued use after the effective date constitutes acceptance.</p>
        </Section>
      </div>
    </main>
  );
}
