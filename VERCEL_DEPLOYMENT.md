# Vercel Deployment Setup for Eco Campus

## Environment Variables to Add in Vercel Dashboard

When deploying on Vercel, go to **Project Settings → Environment Variables** and add:

### Database & Auth (Required)
- **MONGODB_URI**: Your MongoDB connection string  
  Example: `mongodb+srv://user:password@cluster.mongodb.net/`  
  Get this from [MongoDB Atlas](https://www.mongodb.com/cloud/atlas)

- **MONGODB_DB_NAME**: Database name  
  Example: `eco_campus`

- **JWT_ACCESS_SECRET**: Secret for short-lived access tokens (random 32+ char string)  
  Generate: `openssl rand -base64 32`

- **JWT_REFRESH_SECRET**: Secret for refresh tokens (random 32+ char string)  
  Generate: `openssl rand -base64 32`

### Frontend Config
- **CLIENT_URL**: Your Vercel deployment URL  
  Example: `https://eco-campus.vercel.app`

## Deployment Steps

1. **Push to GitHub:**
   ```bash
   git add -A
   git commit -m "Add Vercel deployment config"
   git push origin main
   ```

2. **Deploy on Vercel:**
   - Go to [vercel.com/new](https://vercel.com/new)
   - Select your GitHub repository
   - Choose "Eco Campus" project
   - **Root Directory**: Leave as root (not a subdirectory)
   - Click **Deploy**

3. **Set Environment Variables:**
   - In Vercel Dashboard → Project Settings → Environment Variables
   - Add all variables from the list above
   - Redeploy after adding variables

4. **Initialize Database (one-time):**
   - After deployment, run the init script via API:
   ```bash
   curl https://your-vercel-url.vercel.app/api/health
   ```
   - Then manually call init-db through your monitoring tools

## Result

- **API Server**: Deployed as serverless functions at `https://your-domain.vercel.app/api/*`
- **Web Admin**: Deployed at `https://your-domain.vercel.app/`
- **Analytics**: Automatically tracked via Vercel Analytics

## Notes

- Vercel free tier supports serverless functions and static sites
- MongoDB Atlas free tier gives 512MB database
- Both frontend and API are deployed under one domain
