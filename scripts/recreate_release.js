const fs = require('fs');
const path = require('path');

const token = process.env.GITHUB_TOKEN || process.env.GH_TOKEN;
if (!token) {
  console.error("Error: GITHUB_TOKEN or GH_TOKEN environment variable must be set.");
  process.exit(1);
}
const repo = "shenmareparas/expense_tracker";
const oldReleaseId = "340194429";
const filePath = path.join(__dirname, '../build/app/outputs/flutter-apk/app-release.apk');

async function run() {
  try {
    console.log("Deleting old release...");
    const deleteRes = await fetch(`https://api.github.com/repos/${repo}/releases/${oldReleaseId}`, {
      method: "DELETE",
      headers: {
        "Authorization": `token ${token}`,
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28"
      }
    });
    console.log("Delete release status:", deleteRes.status);
    
    console.log("Creating new release...");
    const createRes = await fetch(`https://api.github.com/repos/${repo}/releases`, {
      method: "POST",
      headers: {
        "Authorization": `token ${token}`,
        "Content-Type": "application/json",
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28"
      },
      body: JSON.stringify({
        tag_name: "v1.0.0",
        name: "Release v1.0.0",
        body: "Updated release of the Expense Tracker app including the new OTP recovery/password reset flow.",
        draft: false,
        prerelease: false
      })
    });
    
    const newRelease = await createRes.json();
    console.log("Create release status:", createRes.status);
    if (createRes.status !== 201) {
      console.error("Failed to create release:", newRelease);
      return;
    }
    
    const newReleaseId = newRelease.id;
    console.log(`New release created with ID: ${newReleaseId}`);
    
    console.log("Uploading APK asset...");
    const fileData = fs.readFileSync(filePath);
    const fileName = path.basename(filePath);
    
    const uploadRes = await fetch(`https://uploads.github.com/repos/${repo}/releases/${newReleaseId}/assets?name=${fileName}`, {
      method: "POST",
      headers: {
        "Authorization": `token ${token}`,
        "Content-Type": "application/vnd.android.package-archive",
        "Content-Length": fileData.length,
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28"
      },
      body: fileData
    });
    
    const responseJson = await uploadRes.json();
    console.log("Upload status:", uploadRes.status);
    if (uploadRes.status === 201) {
      console.log("Success! Asset uploaded:", responseJson.browser_download_url);
    } else {
      console.error("Upload failed:", responseJson);
    }
  } catch (err) {
    console.error(err);
  }
}

run();
