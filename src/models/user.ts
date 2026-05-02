export interface User {
  id: string;
  name: string;
  email: string;
  phone?: string;
}

export interface AuthSession {
  accessToken: string;
  refreshToken: string;
  user: User;
}
