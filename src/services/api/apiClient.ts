import axios, { type AxiosError, type AxiosInstance, type InternalAxiosRequestConfig } from "axios";

import { env } from "@/config/env";
import type { ApiErrorShape } from "@/models/api";

let tokenProvider: (() => string | null) | null = null;

export const setApiTokenProvider = (provider: () => string | null) => {
  tokenProvider = provider;
};

const attachAuthToken = (config: InternalAxiosRequestConfig) => {
  const token = tokenProvider?.();

  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }

  return config;
};

export const apiClient: AxiosInstance = axios.create({
  baseURL: env.apiBaseUrl,
  timeout: env.requestTimeoutMs,
  headers: {
    Accept: "application/json",
    "Content-Type": "application/json"
  }
});

apiClient.interceptors.request.use(attachAuthToken);

export const toApiError = (error: unknown): ApiErrorShape => {
  if (axios.isAxiosError(error)) {
    const axiosError = error as AxiosError<ApiErrorShape>;

    return {
      message: axiosError.response?.data?.message ?? axiosError.message,
      code: axiosError.response?.data?.code,
      status: axiosError.response?.status,
      details: axiosError.response?.data?.details
    };
  }

  return {
    message: error instanceof Error ? error.message : "Something went wrong"
  };
};
