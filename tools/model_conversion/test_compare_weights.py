import unittest
import hashlib
import tempfile
from pathlib import Path

import cv2
import numpy as np

from compare_weights import match, read_case


class MatchingTest(unittest.TestCase):
    def box(self, cls=0, x=.2, confidence=.9):
        return dict(class_index=cls,x=x,y=.2,width=.1,height=.1,confidence=confidence)

    def test_duplicates_cannot_inflate_recall(self):
        result=match([self.box(),self.box()],[self.box()])
        self.assertEqual((result['tp'],result['fp'],result['fn']),(1,1,0))

    def test_wrong_species_and_wrong_location_are_not_true_positives(self):
        result=match([self.box(cls=1),self.box(x=.8)],[self.box()])
        self.assertEqual((result['tp'],result['fp'],result['fn']),(0,2,1))

    def test_negative_frame_counts_every_prediction_as_false_positive(self):
        self.assertEqual(match([self.box()],[])['fp'],1)

    def test_frozen_fixture_hash_is_checked_before_inference(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder); path=root/'fixture.jpg'
            cv2.imwrite(str(path),np.zeros((4,4,3),np.uint8))
            case={'path':path.name,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
            self.assertEqual(read_case(root,case).shape,(4,4,3))
            path.write_bytes(b'changed')
            with self.assertRaisesRegex(ValueError,'Fixture changed'):
                read_case(root,case)

if __name__=='__main__':unittest.main()
