"use client";

import { createContext } from "react";

export const LayerContext = createContext<((closeLayer: () => void) => () => void) | null>(null);
