'use client';

import { useEffect, useState } from 'react';

export interface GameViewportState {
  touch: boolean;
  landscape: boolean;
  compactLandscape: boolean;
}

/**
 * Shared browser-only viewport state for every canvas game.
 * The pure game engine stays browser-free; orientation/safe-area concerns live here.
 */
export function useGameViewport(): GameViewportState {
  const [state, setState] = useState<GameViewportState>({ touch: false, landscape: false, compactLandscape: false });

  useEffect(() => {
    const update = () => {
      const touch = matchMedia('(pointer: coarse)').matches || navigator.maxTouchPoints > 0;
      const landscape = matchMedia('(orientation: landscape)').matches;
      const h = window.visualViewport?.height ?? window.innerHeight;
      setState({ touch, landscape, compactLandscape: touch && landscape && h < 560 });
    };
    update();
    const orientation = matchMedia('(orientation: landscape)');
    const pointer = matchMedia('(pointer: coarse)');
    orientation.addEventListener('change', update);
    pointer.addEventListener('change', update);
    window.addEventListener('resize', update);
    window.visualViewport?.addEventListener('resize', update);
    return () => {
      orientation.removeEventListener('change', update);
      pointer.removeEventListener('change', update);
      window.removeEventListener('resize', update);
      window.visualViewport?.removeEventListener('resize', update);
    };
  }, []);

  return state;
}

/**
 * Fit a fixed-aspect canvas to both width and available viewport height.
 * Landscape phones therefore use the whole screen instead of overflowing below browser chrome.
 */
export function fitGameCanvas(
  canvas: HTMLCanvasElement,
  host: HTMLElement,
  worldWidth: number,
  worldHeight: number,
  compactLandscape: boolean,
): void {
  const dpr = Math.min(window.devicePixelRatio || 1, 2.5);
  const maxWidth = Math.min(worldWidth, host.clientWidth || worldWidth);
  const viewportHeight = window.visualViewport?.height ?? window.innerHeight;
  const heightBudget = compactLandscape ? Math.max(220, viewportHeight - 24) : Number.POSITIVE_INFINITY;
  const width = Math.max(240, Math.min(maxWidth, heightBudget * (worldWidth / worldHeight)));
  const height = width * (worldHeight / worldWidth);
  canvas.width = Math.round(width * dpr);
  canvas.height = Math.round(height * dpr);
  canvas.style.width = `${width}px`;
  canvas.style.height = `${height}px`;
}
