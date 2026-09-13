declare module "@phosphor-icons/react" {
  import type { ComponentType, SVGProps } from "react";

  type IconProps = SVGProps<SVGSVGElement> & {
    size?: string | number;
    weight?: "thin" | "light" | "regular" | "bold" | "fill" | "duotone";
  };

  type Icon = ComponentType<IconProps>;

  export const Bell: Icon;
  export const MagnifyingGlass: Icon;
  export const Mountains: Icon;
  export const Notebook: Icon;
  export const ShieldCheck: Icon;
  export const SignOut: Icon;
  export const SlidersHorizontal: Icon;
  export const SquaresFour: Icon;
  export const Tray: Icon;
  export const UsersThree: Icon;
  export const WarningCircle: Icon;
  export const X: Icon;
}

declare module "@phosphor-icons/react/dist/ssr" {
  export { Tray, WarningCircle } from "@phosphor-icons/react";
}
