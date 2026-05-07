export interface AdminUserDTO {
  id: string;
  displayName: string;
  role: "owner" | "admin" | "reviewer";
  username: string;
}

export interface AdminSessionDTO {
  admin: AdminUserDTO;
  expiresAt: string;
  id: string;
  sessionToken: string;
}

export interface AdminUserRow {
  id: string;
  display_name: string;
  is_active: boolean;
  password_hash: string;
  role: "owner" | "admin" | "reviewer";
  username: string;
}

export interface AdminSessionRow {
  admin_user_id: string;
  expires_at: string;
  id: string;
  revoked_at: string | null;
  session_token_hash: string;
}
