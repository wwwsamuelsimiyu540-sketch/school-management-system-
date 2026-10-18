# SMS delivery setup

The school system stores SMS requests in `school_sms_outbox`. The deployed Supabase Edge Function `send-school-sms` sends one queued message using Africa's Talking and records the provider response.

In the Supabase Dashboard, open **Edge Functions → Secrets** and add:
- `AT_USERNAME`: your Africa's Talking username (use the sandbox username only for sandbox testing).
- `AT_API_KEY`: the API key from your Africa's Talking account.
- `AT_SENDER_ID`: optional approved sender ID; omit it if your account does not have one.

Do not put provider credentials in `index.html`, GitHub source, or client-side settings. Test with a phone number you control first. Sending SMS may incur provider charges. A queued message is not sent until an administrator or bursar clicks its send control and the provider accepts it.
