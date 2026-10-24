export interface User {
  id: string;
  kind: "guest" | "account";
  namespace: string;
}

export interface Bootstrap {
  user: User | null;
  capabilities: {
    online_authority: boolean;
    verified_account: boolean;
  };
  csrf_token: string;
}
