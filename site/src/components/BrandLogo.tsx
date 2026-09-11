/** One outlined asset for the masthead, footer and profile navigation. */
export function BrandLogo({ className = '', light = false }: { className?: string; light?: boolean }) {
  return (
    <img
      src={light ? '/brand/poz-wordmark-light.svg' : '/brand/poz-wordmark.svg'}
      alt="POZ"
      width={780}
      height={310}
      className={`block h-auto shrink-0 ${className}`}
    />
  );
}
