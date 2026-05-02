import type { AuthSession } from "@/models/user";
import { apiClient } from "@/services/api/apiClient";

export interface LoginPayload {
  email: string;
  password: string;
}

export const authApi = {
  async login(payload: LoginPayload): Promise<AuthSession> {
    const response = await apiClient.post<AuthSession>("/auth/login", payload);
    return response.data;
  }
};
