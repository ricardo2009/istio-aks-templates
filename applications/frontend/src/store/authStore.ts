import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import axios from 'axios';

// Types
interface User {
  id: string;
  email: string;
  name: string;
  role: string;
  avatar?: string;
}

interface AuthState {
  user: User | null;
  token: string | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  error: string | null;
}

interface AuthActions {
  login: (email: string, password: string) => Promise<void>;
  register: (userData: RegisterData) => Promise<void>;
  logout: () => void;
  refreshToken: () => Promise<void>;
  clearError: () => void;
  updateProfile: (userData: Partial<User>) => Promise<void>;
}

interface RegisterData {
  name: string;
  email: string;
  password: string;
  confirmPassword: string;
}

type AuthStore = AuthState & AuthActions;

// API Configuration
const API_BASE_URL = process.env.REACT_APP_API_URL || '/api/v1';

// Axios instance with interceptors
const apiClient = axios.create({
  baseURL: API_BASE_URL,
  timeout: 10000,
});

// Request interceptor to add auth token
apiClient.interceptors.request.use(
  (config) => {
    const token = useAuthStore.getState().token;
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error) => Promise.reject(error)
);

// Response interceptor to handle token refresh
apiClient.interceptors.response.use(
  (response) => response,
  async (error) => {
    const originalRequest = error.config;
    
    if (error.response?.status === 401 && !originalRequest._retry) {
      originalRequest._retry = true;
      
      try {
        await useAuthStore.getState().refreshToken();
        const token = useAuthStore.getState().token;
        originalRequest.headers.Authorization = `Bearer ${token}`;
        return apiClient(originalRequest);
      } catch (refreshError) {
        useAuthStore.getState().logout();
        window.location.href = '/login';
        return Promise.reject(refreshError);
      }
    }
    
    return Promise.reject(error);
  }
);

// Zustand store
export const useAuthStore = create<AuthStore>()(
  persist(
    (set, get) => ({
      // Initial state
      user: null,
      token: null,
      isAuthenticated: false,
      isLoading: false,
      error: null,

      // Actions
      login: async (email: string, password: string) => {
        set({ isLoading: true, error: null });
        
        try {
          const response = await apiClient.post('/auth/login', {
            email,
            password,
          });
          
          const { user, token, refreshToken } = response.data;
          
          // Store refresh token in httpOnly cookie (handled by backend)
          set({
            user,
            token,
            isAuthenticated: true,
            isLoading: false,
            error: null,
          });
          
          // Set up token refresh timer
          scheduleTokenRefresh(token);
          
        } catch (error: any) {
          const errorMessage = error.response?.data?.message || 'Login failed';
          set({
            isLoading: false,
            error: errorMessage,
            isAuthenticated: false,
          });
          throw new Error(errorMessage);
        }
      },

      register: async (userData: RegisterData) => {
        set({ isLoading: true, error: null });
        
        try {
          if (userData.password !== userData.confirmPassword) {
            throw new Error('Passwords do not match');
          }
          
          const response = await apiClient.post('/auth/register', {
            name: userData.name,
            email: userData.email,
            password: userData.password,
          });
          
          const { user, token } = response.data;
          
          set({
            user,
            token,
            isAuthenticated: true,
            isLoading: false,
            error: null,
          });
          
          scheduleTokenRefresh(token);
          
        } catch (error: any) {
          const errorMessage = error.response?.data?.message || 'Registration failed';
          set({
            isLoading: false,
            error: errorMessage,
            isAuthenticated: false,
          });
          throw new Error(errorMessage);
        }
      },

      logout: () => {
        // Clear token refresh timer
        clearTokenRefreshTimer();
        
        // Call logout endpoint to invalidate refresh token
        apiClient.post('/auth/logout').catch(() => {
          // Ignore errors on logout
        });
        
        set({
          user: null,
          token: null,
          isAuthenticated: false,
          isLoading: false,
          error: null,
        });
      },

      refreshToken: async () => {
        try {
          const response = await apiClient.post('/auth/refresh');
          const { token } = response.data;
          
          set({ token });
          scheduleTokenRefresh(token);
          
        } catch (error) {
          get().logout();
          throw error;
        }
      },

      clearError: () => {
        set({ error: null });
      },

      updateProfile: async (userData: Partial<User>) => {
        set({ isLoading: true, error: null });
        
        try {
          const response = await apiClient.put('/users/profile', userData);
          const updatedUser = response.data;
          
          set({
            user: updatedUser,
            isLoading: false,
            error: null,
          });
          
        } catch (error: any) {
          const errorMessage = error.response?.data?.message || 'Profile update failed';
          set({
            isLoading: false,
            error: errorMessage,
          });
          throw new Error(errorMessage);
        }
      },
    }),
    {
      name: 'auth-storage',
      partialize: (state) => ({
        user: state.user,
        token: state.token,
        isAuthenticated: state.isAuthenticated,
      }),
    }
  )
);

// Token refresh utilities
let tokenRefreshTimer: NodeJS.Timeout | null = null;

function scheduleTokenRefresh(token: string) {
  clearTokenRefreshTimer();
  
  try {
    // Decode JWT to get expiration time
    const payload = JSON.parse(atob(token.split('.')[1]));
    const expirationTime = payload.exp * 1000; // Convert to milliseconds
    const currentTime = Date.now();
    const refreshTime = expirationTime - currentTime - 5 * 60 * 1000; // Refresh 5 minutes before expiration
    
    if (refreshTime > 0) {
      tokenRefreshTimer = setTimeout(() => {
        useAuthStore.getState().refreshToken().catch(() => {
          useAuthStore.getState().logout();
        });
      }, refreshTime);
    }
  } catch (error) {
    console.error('Error scheduling token refresh:', error);
  }
}

function clearTokenRefreshTimer() {
  if (tokenRefreshTimer) {
    clearTimeout(tokenRefreshTimer);
    tokenRefreshTimer = null;
  }
}

// Initialize token refresh on app start
const { token } = useAuthStore.getState();
if (token) {
  scheduleTokenRefresh(token);
}

export { apiClient };
