import { createContext, useContext, useState, type ReactNode } from "react";
import { useAuth } from "@/lib/use-auth";

type EditModeContextValue = {
  /** True only when an admin has actively turned edit mode on. */
  editMode: boolean;
  setEditMode: (value: boolean) => void;
  /** Whether the current user is allowed to edit at all (admin). */
  canEdit: boolean;
};

const EditModeContext = createContext<EditModeContextValue>({
  editMode: false,
  setEditMode: () => {},
  canEdit: false,
});

export function EditModeProvider({ children }: { children: ReactNode }) {
  const { isAdmin } = useAuth();
  const [editMode, setEditMode] = useState(false);

  // A non-admin (or a logged-out admin) can never be in edit mode.
  const value: EditModeContextValue = {
    editMode: isAdmin && editMode,
    setEditMode,
    canEdit: isAdmin,
  };

  return <EditModeContext.Provider value={value}>{children}</EditModeContext.Provider>;
}

export function useEditMode() {
  return useContext(EditModeContext);
}
