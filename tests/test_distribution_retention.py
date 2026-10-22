import sys,tempfile,json,zipfile,unittest
from pathlib import Path
sys.path.insert(0,str(Path('tools/network').resolve()))
from publish_update import prune_distribution_packages
class Checks(unittest.TestCase):
 def test_retention(self):
  with tempfile.TemporaryDirectory() as temp:
   root=Path(temp)
   for version in ['1','2','3']:
    name='Windrest-AutoUpdate-2026.10.22.'+version
    (root/name).mkdir();(root/name/'current.json').write_text(json.dumps({'version':'2026.10.22.'+version}))
    with zipfile.ZipFile(root/(name+'.zip'),'w') as z:z.writestr('test','ok')
   for name in ['deployment-backups','network-v0.1.0','other-stage']:(root/name).mkdir()
   removed=prune_distribution_packages(root,'2026.10.22.3')
   self.assertEqual(len(removed),2)
   self.assertTrue((root/'Windrest-AutoUpdate-2026.10.22.2').exists())
   self.assertTrue((root/'Windrest-AutoUpdate-2026.10.22.3.zip').exists())
   self.assertTrue((root/'deployment-backups').exists())
   self.assertTrue((root/'network-v0.1.0').exists())
   self.assertTrue((root/'other-stage').exists())
   self.assertEqual(prune_distribution_packages(root,'2026.10.22.3'),[])
 def test_incomplete_does_not_delete(self):
  with tempfile.TemporaryDirectory() as temp:
   root=Path(temp)
   for v in ['1','2','3']:(root/('Windrest-AutoUpdate-2026.10.22.'+v)).mkdir()
   self.assertEqual(prune_distribution_packages(root,'2026.10.22.3'),[])
   self.assertEqual(len(list(root.iterdir())),3)
 def test_locked_retries(self):
  from unittest.mock import patch
  with tempfile.TemporaryDirectory() as temp:
   root=Path(temp)
   for v in ['1','2','3']:
    name='Windrest-AutoUpdate-2026.10.22.'+v;(root/name).mkdir()
    (root/name/'current.json').write_text(json.dumps({'version':'2026.10.22.'+v}))
    with zipfile.ZipFile(root/(name+'.zip'),'w') as z:z.writestr('test','ok')
   with patch('publish_update.shutil.rmtree',side_effect=PermissionError):prune_distribution_packages(root,'2026.10.22.3')
   self.assertTrue((root/'Windrest-AutoUpdate-2026.10.22.1').exists())
   self.assertEqual(prune_distribution_packages(root,'2026.10.22.3'),['Windrest-AutoUpdate-2026.10.22.1'])
unittest.main()
