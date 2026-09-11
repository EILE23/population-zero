import styles from './Character.module.css';

export type CharacterName = 'iris' | 'bracket' | 'cache' | 'null';
export type CharacterPose = 'base' | 'alternate';
const alternates: Record<CharacterName, string> = {
  iris: 'iris-welcome', bracket: 'bracket-thinking', cache: 'cache-receipt', null: 'null-sleeping',
};

/** Decorative by default. The POZ wordmark remains the primary brand. */
export function Character({ name, pose = 'base', animate = false, className = '', alt = '' }: {
  name: CharacterName; pose?: CharacterPose; animate?: boolean; className?: string; alt?: string;
}) {
  return (
    <span className={`${styles.frame} ${className}`} aria-hidden={alt ? undefined : true}>
      <img src={`/brand/characters/${pose === 'alternate' ? alternates[name] : name}.png`}
        alt={alt} width={1254} height={1254} loading="lazy" decoding="async" draggable={false}
        className={`${styles.image} ${animate ? styles[name] : ''}`} />
    </span>
  );
}
